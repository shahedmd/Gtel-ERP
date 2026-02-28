// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gtel_erp/Stock/controller.dart'; // Adjust if needed

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final int _pageSize = 15;
  bool _isLoading = false;
  bool _hasMore = true;

  List<DocumentSnapshot> _orders = [];
  final List<DocumentSnapshot> _pageStartDocs = [];

  // --- ADDED SCROLL CONTROLLERS TO FIX THE SCROLLBAR CRASH ---
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  // --- PAGINATION LOGIC ---

  Future<void> _fetchFirstPage() async {
    setState(() => _isLoading = true);
    try {
      var snap =
          await FirebaseFirestore.instance
              .collection('order_history')
              .orderBy('date', descending: true)
              .limit(_pageSize)
              .get();
      _orders = snap.docs;
      if (_orders.isNotEmpty) {
        _pageStartDocs.clear();
        _pageStartDocs.add(_orders.first);
      }
      _hasMore = _orders.length == _pageSize;
    } catch (e) {
      Get.snackbar("Error", "Failed to load: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNextPage() async {
    if (_orders.isEmpty || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      var snap =
          await FirebaseFirestore.instance
              .collection('order_history')
              .orderBy('date', descending: true)
              .startAfterDocument(_orders.last)
              .limit(_pageSize)
              .get();

      if (snap.docs.isNotEmpty) {
        _orders = snap.docs;
        _pageStartDocs.add(_orders.first);
        _hasMore = _orders.length == _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load next page: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchPrevPage() async {
    if (_pageStartDocs.length > 1) {
      setState(() => _isLoading = true);
      try {
        _pageStartDocs.removeLast();
        var targetDoc = _pageStartDocs.last;

        var snap =
            await FirebaseFirestore.instance
                .collection('order_history')
                .orderBy('date', descending: true)
                .startAtDocument(targetDoc)
                .limit(_pageSize)
                .get();

        _orders = snap.docs;
        _hasMore = true;
      } catch (e) {
        Get.snackbar("Error", "Failed to load previous page: $e");
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCurrentPage() async {
    if (_pageStartDocs.isEmpty) {
      return _fetchFirstPage();
    }
    setState(() => _isLoading = true);
    var targetDoc = _pageStartDocs.last;
    var snap =
        await FirebaseFirestore.instance
            .collection('order_history')
            .orderBy('date', descending: true)
            .startAtDocument(targetDoc)
            .limit(_pageSize)
            .get();
    _orders = snap.docs;
    _hasMore = _orders.length == _pageSize;
    setState(() => _isLoading = false);
  }

  Color _getStatusColor(String status) {
    if (status == 'Pending') return const Color(0xFFF59E0B);
    if (status == 'On the way') return const Color(0xFF3B82F6);
    if (status == 'Complete') return const Color(0xFF10B981);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Purchase Order History",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TABLE HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Order Records",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF334155),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: _refreshCurrentPage,
                          tooltip: "Refresh List",
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // --- DATA TABLE ---
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _orders.isEmpty
                            ? const Center(
                              child: Text(
                                "No order history found.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                            : LayoutBuilder(
                              builder: (context, constraints) {
                                // This layout builder fixes the 40% width issue by forcing the table to expand.
                                return Scrollbar(
                                  controller: _horizontalScroll,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScroll,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: SingleChildScrollView(
                                        controller: _verticalScroll,
                                        scrollDirection: Axis.vertical,
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            dividerColor: const Color(
                                              0xFFE2E8F0,
                                            ),
                                            dataTableTheme: DataTableThemeData(
                                              headingRowColor:
                                                  WidgetStateProperty.all(
                                                    const Color(0xFFF8FAFC),
                                                  ),
                                            ),
                                          ),
                                          child: DataTable(
                                            headingRowHeight: 56,
                                            dataRowMinHeight: 60,
                                            dataRowMaxHeight: 60,
                                            horizontalMargin: 24,
                                            columnSpacing: 32,
                                            showBottomBorder: true,
                                            columns: [
                                              _col("S/N", isNumeric: true),
                                              _col("Date"),
                                              _col("Company Name"),
                                              _col(
                                                "Via",
                                                align: MainAxisAlignment.center,
                                              ),
                                              _col(
                                                "Total Items",
                                                align: MainAxisAlignment.center,
                                              ),
                                              _col(
                                                "Status",
                                                align: MainAxisAlignment.center,
                                              ),
                                              _col(
                                                "Action",
                                                align: MainAxisAlignment.center,
                                              ),
                                            ],
                                            rows: List.generate(_orders.length, (
                                              index,
                                            ) {
                                              final doc = _orders[index];
                                              final data =
                                                  doc.data()
                                                      as Map<String, dynamic>;

                                              String dateStr = "N/A";
                                              if (data['date'] != null) {
                                                DateTime dt =
                                                    (data['date'] as Timestamp)
                                                        .toDate();
                                                dateStr =
                                                    "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                                              }

                                              final int serial =
                                                  ((_pageStartDocs.length - 1) *
                                                      _pageSize) +
                                                  index +
                                                  1;
                                              final totalItems =
                                                  data['total_items'] ?? 0;
                                              final status =
                                                  data['status'] ?? 'Pending';
                                              final companyName =
                                                  data['company_name'] ?? 'N/A';
                                              final delivery =
                                                  data['delivery_method'] ??
                                                  'N/A';
                                              final color =
                                                  index.isEven
                                                      ? Colors.white
                                                      : const Color(0xFFF8FAFC);

                                              return DataRow(
                                                color: WidgetStateProperty.all(
                                                  color,
                                                ),
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      "$serial",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      dateStr,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF475569,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      companyName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF0F172A,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: Text(delivery),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: Text(
                                                        "$totalItems",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: _buildStatusBadge(
                                                        status,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: _buildActionMenu(
                                                        doc.id,
                                                        status,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // --- PAGINATION FOOTER ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Page ${_pageStartDocs.isEmpty ? 1 : _pageStartDocs.length}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _pageStartDocs.length > 1 && !_isLoading
                                      ? _fetchPrevPage
                                      : null,
                              icon: const Icon(Icons.chevron_left, size: 18),
                              label: const Text("Previous"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed:
                                  _hasMore && !_isLoading
                                      ? _fetchNextPage
                                      : null,
                              icon: const Text("Next"),
                              label: const Icon(Icons.chevron_right, size: 18),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  DataColumn _col(
    String label, {
    bool isNumeric = false,
    MainAxisAlignment align = MainAxisAlignment.start,
  }) {
    return DataColumn(
      numeric: isNumeric,
      label: Expanded(
        child: Row(
          mainAxisAlignment: align,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
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
      text = const Color(0xFF2563EB);
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildActionMenu(String docId, String currentStatus) {
    return PopupMenuButton<String>(
      tooltip: "Actions",
      icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'view') {
          _showOrderDetails(context, docId).then((_) => _refreshCurrentPage());
        } else if (value == 'status') {
          _changeOrderStatusDialog(docId, currentStatus);
        } else if (value == 'delete') {
          _deleteFullOrderDialog(docId);
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 10),
                  Text('View / Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'status',
              child: Row(
                children: [
                  Icon(Icons.sync_alt, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 10),
                  Text('Change Status'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Delete Order',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  // --- QUICK ACTION DIALOGS ---

  void _changeOrderStatusDialog(String docId, String currentStatus) {
    String selectedStatus = currentStatus;
    Get.dialog(
      AlertDialog(
        title: const Text("Update Order Status"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items:
                  ['Pending', 'On the way', 'Complete']
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(e),
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) setDialogState(() => selectedStatus = val);
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back();
              setState(() => _isLoading = true);
              await FirebaseFirestore.instance
                  .collection('order_history')
                  .doc(docId)
                  .update({'status': selectedStatus});
              await _refreshCurrentPage();
              Get.snackbar(
                "Success",
                "Status changed to $selectedStatus",
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
      middleText:
          "This action cannot be undone. Are you sure you want to delete this purchase order?",
      textConfirm: "Yes, Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFFDC2626),
      cancelTextColor: const Color(0xFF0F172A),
      onConfirm: () async {
        Get.back();
        setState(() => _isLoading = true);
        await FirebaseFirestore.instance
            .collection('order_history')
            .doc(docId)
            .delete();
        await _refreshCurrentPage();
        Get.snackbar(
          "Deleted",
          "Purchase order has been permanently deleted.",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      },
    );
  }

  // --- FULL ORDER DETAILS DIALOG (VIEW/EDIT LIST) ---

  Future<void> _showOrderDetails(BuildContext context, String docId) async {
    // Determine a responsive width for the Dialog so it looks perfect & centered
    double dialogWidth = MediaQuery.of(context).size.width * 0.7;
    if (dialogWidth > 1100) dialogWidth = 1100;
    if (dialogWidth < 600) dialogWidth = 600;

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(maxHeight: 800),
          padding: const EdgeInsets.all(24),
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
                DateTime dt = (data['date'] as Timestamp).toDate();
                dateStr =
                    "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Details - $dateStr",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1),

                  // Header Info & Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Company: $company",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            "Via: $delivery   |   Status: $status",
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                () => _showAddProductDialog(docId, items),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add Product"),
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
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text("Reprint"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Items List
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
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ListTile(
                                    title: Text(
                                      item['model'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(item['name']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_square,
                                            color: Colors.blueGrey,
                                          ),
                                          tooltip: "Edit Qty",
                                          onPressed:
                                              () => _editItemQuantity(
                                                docId,
                                                items,
                                                index,
                                                item['order_qty'],
                                              ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
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
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          tooltip: "Remove Product",
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

  // --- List Item Modifier Functions ---

  void _editItemQuantity(
    String docId,
    List currentItems,
    int index,
    int currentQty,
  ) {
    TextEditingController qtyCtrl = TextEditingController(
      text: currentQty.toString(),
    );
    Get.dialog(
      AlertDialog(
        title: const Text("Edit Quantity"),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int newQty = int.tryParse(qtyCtrl.text) ?? 0;
              if (newQty > 0) {
                currentItems[index]['order_qty'] = newQty;
                await FirebaseFirestore.instance
                    .collection('order_history')
                    .doc(docId)
                    .update({'items': currentItems});
                Get.back();
              }
            },
            child: const Text("Save"),
          ),
        ],
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
          Get.back();
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

  void _showAddProductDialog(String docId, List currentItems) {
    final ProductController prodCtrl = Get.find<ProductController>();
    RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
    RxBool isSearching = false.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                decoration: const InputDecoration(
                  hintText: "Type Model or Name to search...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) async {
                  if (val.length < 2) {
                    searchResults.clear();
                    return;
                  }
                  isSearching.value = true;
                  var results = await prodCtrl.searchProductsForDropdown(val);
                  searchResults.assignAll(results);
                  isSearching.value = false;
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (isSearching.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (searchResults.isEmpty) {
                    return const Center(
                      child: Text("No results. Type to search."),
                    );
                  }
                  return ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final productMap = searchResults[index];
                      return ListTile(
                        title: Text(
                          productMap['model'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(productMap['name']),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              () => _promptQtyAndAdd(
                                docId,
                                currentItems,
                                productMap,
                              ),
                          child: const Text("Select"),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptQtyAndAdd(
    String docId,
    List currentItems,
    Map<String, dynamic> selectedProduct,
  ) {
    TextEditingController qtyCtrl = TextEditingController(text: "1");
    Get.dialog(
      AlertDialog(
        title: Text("Add ${selectedProduct['model']}"),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Order Quantity",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
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
    );
  }
}

// --- Professional Order PDF Generator for History --- //
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
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "PURCHASE ORDER LIST",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    "Order Date: $orderDate",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
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
                        "Company Name: $company",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "Delivery Via: $delivery",
                        style: const pw.TextStyle(color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Status: $status",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color:
                          status == 'Complete'
                              ? PdfColors.green800
                              : PdfColors.orange800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue100,
              ),
              headerHeight: 40,
              cellHeight: 30,
              headerStyle: pw.TextStyle(
                color: PdfColors.black,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: ['No.', 'Product Name', 'Model', 'Order Quantity'],
              data: List<List<String>>.generate(
                items.length,
                (index) => [
                  (index + 1).toString(),
                  items[index]['name'] ?? '-',
                  items[index]['model'] ?? '-',
                  items[index]['order_qty'].toString(),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Total Ordered Models: ${items.length}",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
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
