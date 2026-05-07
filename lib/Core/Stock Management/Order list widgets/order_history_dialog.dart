import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../Menubar and Navigation/app_pages.dart';
import '../../../Permission/permission_button.dart';
import '../../Core Utils/activity_logger.dart';
import '../china_order_list.dart';
import '../stock_controller.dart';
import 'order_history_pdf.dart';

void showOrderDetailDialog({
  required BuildContext context,
  required String docId,
  required OrderHistoryController ctrl,
}) {
  final bool isMobile = MediaQuery.of(context).size.width < 600;

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _OrderDetailContent(docId: docId, ctrl: ctrl, isMobile: isMobile),
    ),
  ).then((_) => ctrl.refreshCurrentPage());
}

// ─────────────────────────────────────────────────────────────
// Dialog content — StreamBuilder for real-time updates
// ─────────────────────────────────────────────────────────────
class _OrderDetailContent extends StatelessWidget {
  final String docId;
  final OrderHistoryController ctrl;
  final bool isMobile;

  const _OrderDetailContent({
    required this.docId,
    required this.ctrl,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          final dateStr = _formatDate(data['date']);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header
              _DialogHeader(isMobile: isMobile),

              const Divider(thickness: 1),

              // Order info + action buttons
              _OrderInfoSection(
                company: company,
                dateStr: dateStr,
                delivery: delivery,
                status: status,
                items: items,
                docId: docId,
                data: data,
                ctrl: ctrl,
                isMobile: isMobile,
              ),

              const SizedBox(height: 16),
              const Text(
                'Ordered Items',
                style: TextStyle(fontWeight: FontWeight.bold, color: textDark),
              ),
              const SizedBox(height: 8),

              // Items list
              Expanded(
                child:
                    items.isEmpty
                        ? const Center(
                          child: Text(
                            'No items left in this order.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : _ItemsList(items: items, docId: docId, ctrl: ctrl),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dialog Header
// ─────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final bool isMobile;

  const _DialogHeader({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Order Details',
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: darkSlate,
          ),
        ),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Order Info + Buttons
// ─────────────────────────────────────────────────────────────
class _OrderInfoSection extends StatelessWidget {
  final String company;
  final String dateStr;
  final String delivery;
  final String status;
  final List items;
  final String docId;
  final Map<String, dynamic> data;
  final OrderHistoryController ctrl;
  final bool isMobile;

  const _OrderInfoSection({
    required this.company,
    required this.dateStr,
    required this.delivery,
    required this.status,
    required this.items,
    required this.docId,
    required this.data,
    required this.ctrl,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final addItemBtn = PermissionButton(
      route: Routes.orderlist,
      type: PermissionType.canEdit,
      showDisabled: true,
      child: ElevatedButton.icon(
        onPressed: () => _showAddProductDialog(docId, items),
        icon: const Icon(Icons.add, size: 16),
        label: Text(isMobile ? 'Add' : 'Add Item'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
        ),
      ),
    );

    final reprintBtn = ElevatedButton.icon(
      onPressed:
          items.isEmpty
              ? null
              : () => OrderHistoryPdf.generate(items, data, dateStr),
      icon: const Icon(Icons.print, size: 16),
      label: Text(isMobile ? 'Reprint' : 'Reprint PO'),
      style: ElevatedButton.styleFrom(
        backgroundColor: activeAccent,
        foregroundColor: Colors.white,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoText(
                    company: company,
                    dateStr: dateStr,
                    delivery: delivery,
                    status: status,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: addItemBtn),
                      const SizedBox(width: 8),
                      Expanded(child: reprintBtn),
                    ],
                  ),
                ],
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _InfoText(
                      company: company,
                      dateStr: dateStr,
                      delivery: delivery,
                      status: status,
                    ),
                  ),
                  Row(
                    children: [
                      addItemBtn,
                      const SizedBox(width: 10),
                      reprintBtn,
                    ],
                  ),
                ],
              ),
    );
  }

  void _showAddProductDialog(String docId, List currentItems) {
    Get.dialog(
      _AddProductDialog(docId: docId, currentItems: currentItems, ctrl: ctrl),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String company;
  final String dateStr;
  final String delivery;
  final String status;

  const _InfoText({
    required this.company,
    required this.dateStr,
    required this.delivery,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier: $company',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Date: $dateStr\nVia: $delivery | Status: $status',
          style: const TextStyle(color: textDark, fontSize: 12),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Items List
// ─────────────────────────────────────────────────────────────
class _ItemsList extends StatelessWidget {
  final List items;
  final String docId;
  final OrderHistoryController ctrl;

  const _ItemsList({
    required this.items,
    required this.docId,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              item['model'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(item['name'], style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit qty — canEdit permission
                PermissionButton(
                  route: Routes.orderlist,
                  type: PermissionType.canEdit,
                  showDisabled: true,
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_square,
                      color: Colors.blueGrey,
                      size: 20,
                    ),
                    onPressed:
                        () => _showEditQtyDialog(
                          docId,
                          items,
                          index,
                          item['order_qty'],
                        ),
                  ),
                ),

                // Qty badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${item['order_qty']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Delete item — canDelete permission
                PermissionButton(
                  route: Routes.orderlist,
                  type: PermissionType.canDelete,
                  showDisabled: true,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _confirmDeleteItem(docId, items, index),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditQtyDialog(String docId, List items, int index, int currentQty) {
    Get.dialog(
      _EditQtyDialog(
        docId: docId,
        items: items,
        index: index,
        currentQty: currentQty,
        ctrl: ctrl,
      ),
    );
  }

  void _confirmDeleteItem(String docId, List items, int index) {
    Get.defaultDialog(
      title: 'Remove Item?',
      middleText: 'Remove this product from the order?',
      textConfirm: 'Remove',
      textCancel: 'Cancel',
      buttonColor: Colors.red,
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back();
        final itemName = items[index]['model'];
        await ctrl.deleteItemFromOrder(docId, items, index);
        await ActivityLogger.log(
          action: 'REMOVE_ORDER_ITEM',
          module: 'Stock',
          details: '$itemName removed from order $docId',
        );
        if (items.isEmpty) Get.back();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Qty Dialog
// ─────────────────────────────────────────────────────────────
class _EditQtyDialog extends StatefulWidget {
  final String docId;
  final List items;
  final int index;
  final int currentQty;
  final OrderHistoryController ctrl;

  const _EditQtyDialog({
    required this.docId,
    required this.items,
    required this.index,
    required this.currentQty,
    required this.ctrl,
  });

  @override
  State<_EditQtyDialog> createState() => _EditQtyDialogState();
}

class _EditQtyDialogState extends State<_EditQtyDialog> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.currentQty.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Edit Quantity',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: TextField(
        controller: _qtyCtrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final qty = int.tryParse(_qtyCtrl.text) ?? 0;
            if (qty > 0) {
              await widget.ctrl.updateItemQty(
                widget.docId,
                widget.items,
                widget.index,
                qty,
              );
              await ActivityLogger.log(
                action: 'EDIT_ORDER_QTY',
                module: 'Stock',
                details:
                    'Order ${widget.docId} item[${widget.index}] qty → $qty',
              );
              Get.back();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add Product Dialog
// ─────────────────────────────────────────────────────────────
class _AddProductDialog extends StatelessWidget {
  final String docId;
  final List currentItems;
  final OrderHistoryController ctrl;

  _AddProductDialog({
    required this.docId,
    required this.currentItems,
    required this.ctrl,
  });

  final ProductController _prodCtrl = Get.find<ProductController>();
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;

  void _search(String val) async {
    if (val.length < 2) {
      searchResults.clear();
      return;
    }
    isSearching.value = true;
    final results = await _prodCtrl.searchProductsForDropdown(val);
    searchResults.assignAll(results);
    isSearching.value = false;
  }

  void _promptQtyAndAdd(Map<String, dynamic> product) {
    final qtyCtrl = TextEditingController(text: '1');

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Add ${product['model']}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Order Quantity',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty > 0) {
                await ctrl.addItemToOrder(docId, currentItems, product, qty);
                await ActivityLogger.log(
                  action: 'ADD_ORDER_ITEM',
                  module: 'Stock',
                  details:
                      '${product['model']} added to order $docId | Qty: $qty',
                );
                Get.back(); // qty dialog
                Get.back(); // search dialog
                Get.snackbar(
                  'Added',
                  '${product['model']} added to order',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Add to Order'),
          ),
        ],
      ),
    ).then((_) => qtyCtrl.dispose());
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
                  'Search & Add Product',
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
                hintText: 'Type model or name to search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                if (isSearching.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (searchResults.isEmpty) {
                  return const Center(
                    child: Text(
                      'No results. Type to search.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = searchResults[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p['model'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        p['name'],
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
                        onPressed: () => _promptQtyAndAdd(p),
                        child: const Text('Select'),
                      ),
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

// Helper
String _formatDate(dynamic timestamp) {
  if (timestamp == null) return 'N/A';
  try {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format((timestamp as Timestamp).toDate());
  } catch (_) {
    return 'N/A';
  }
}