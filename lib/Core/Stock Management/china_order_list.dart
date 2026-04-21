import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Core Utils/app_logger.dart';
import 'Order list widgets/order_history_table.dart';
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int pageSize = 15;

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
    try {
      isLoading.value = true;
      final snap =
          await _db
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
      AppLogger.e('fetchFirstPage error: $e');
      _showError('Failed to load orders');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchNextPage() async {
    if (orders.isEmpty || !hasMore.value) return;
    try {
      isLoading.value = true;
      final snap =
          await _db
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
      AppLogger.e('fetchNextPage error: $e');
      _showError('Failed to load next page');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPrevPage() async {
    if (pageStartDocs.length <= 1) return;
    try {
      isLoading.value = true;
      pageStartDocs.removeLast();
      final snap =
          await _db
              .collection('order_history')
              .orderBy('date', descending: true)
              .startAtDocument(pageStartDocs.last)
              .limit(pageSize)
              .get();

      orders.assignAll(snap.docs);
      hasMore.value = true;
    } catch (e) {
      AppLogger.e('fetchPrevPage error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshCurrentPage() async {
    if (pageStartDocs.isEmpty) return fetchFirstPage();
    try {
      isLoading.value = true;
      final snap =
          await _db
              .collection('order_history')
              .orderBy('date', descending: true)
              .startAtDocument(pageStartDocs.last)
              .limit(pageSize)
              .get();

      orders.assignAll(snap.docs);
      hasMore.value = orders.length == pageSize;
    } catch (e) {
      AppLogger.e('refreshCurrentPage error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Status update
  Future<void> updateOrderStatus(String docId, String newStatus) async {
    try {
      await _db.collection('order_history').doc(docId).update({
        'status': newStatus,
      });
      await refreshCurrentPage();
    } catch (e) {
      AppLogger.e('updateOrderStatus error: $e');
      _showError('Failed to update status');
    }
  }

  // Delete full order
  Future<void> deleteOrder(String docId) async {
    try {
      await _db.collection('order_history').doc(docId).delete();
      await refreshCurrentPage();
    } catch (e) {
      AppLogger.e('deleteOrder error: $e');
      _showError('Failed to delete order');
    }
  }

  // Delete single item from order
  Future<void> deleteItemFromOrder(String docId, List items, int index) async {
    try {
      items.removeAt(index);
      if (items.isEmpty) {
        await _db.collection('order_history').doc(docId).delete();
      } else {
        await _db.collection('order_history').doc(docId).update({
          'items': items,
          'total_items': items.length,
        });
      }
    } catch (e) {
      AppLogger.e('deleteItemFromOrder error: $e');
      _showError('Failed to remove item');
    }
  }

  // Update item qty
  Future<void> updateItemQty(
    String docId,
    List items,
    int index,
    int qty,
  ) async {
    try {
      items[index]['order_qty'] = qty;
      await _db.collection('order_history').doc(docId).update({'items': items});
    } catch (e) {
      AppLogger.e('updateItemQty error: $e');
      _showError('Failed to update quantity');
    }
  }

  // Add item to existing order
  Future<void> addItemToOrder(
    String docId,
    List currentItems,
    Map<String, dynamic> product,
    int qty,
  ) async {
    try {
      final existingIndex = currentItems.indexWhere(
        (item) => item['product_id'] == product['id'],
      );

      if (existingIndex != -1) {
        currentItems[existingIndex]['order_qty'] += qty;
      } else {
        currentItems.add({
          'product_id': product['id'],
          'model': product['model'],
          'name': product['name'],
          'order_qty': qty,
        });
      }

      await _db.collection('order_history').doc(docId).update({
        'items': currentItems,
        'total_items': currentItems.length,
      });
    } catch (e) {
      AppLogger.e('addItemToOrder error: $e');
      _showError('Failed to add item');
    }
  }

  int get currentPageNumber => pageStartDocs.isEmpty ? 1 : pageStartDocs.length;

  void _showError(String msg) => Get.snackbar(
    'Error',
    msg,
    backgroundColor: Colors.redAccent,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
  );
}

// ─────────────────────────────────────────────────────────────
// OrderHistoryPage — main page
// ─────────────────────────────────────────────────────────────
class OrderHistoryPage extends StatelessWidget {
  OrderHistoryPage({super.key});

  final OrderHistoryController ctrl = Get.put(OrderHistoryController());

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
              'Purchase Order History',
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
                children: [
                  // Header
                  _PageHeader(ctrl: ctrl),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Table / Cards
                  Expanded(
                    child: Obx(() {
                      if (ctrl.isLoading.value) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        );
                      }
                      if (ctrl.orders.isEmpty) {
                        return const _EmptyState();
                      }
                      return OrderHistoryTable(isMobile: isMobile, ctrl: ctrl);
                    }),
                  ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Pagination
                  _PaginationFooter(isMobile: isMobile, ctrl: ctrl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Page Header
// ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final OrderHistoryController ctrl;

  const _PageHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Order Records',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: darkSlate,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: ctrl.refreshCurrentPage,
            tooltip: 'Refresh',
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
}

// ─────────────────────────────────────────────────────────────
// Pagination Footer
// ─────────────────────────────────────────────────────────────
class _PaginationFooter extends StatelessWidget {
  final bool isMobile;
  final OrderHistoryController ctrl;

  const _PaginationFooter({required this.isMobile, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: 12,
        ),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isMobile)
              Text(
                'Page ${ctrl.currentPageNumber}',
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
                  label: const Text('Prev'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: darkSlate,
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed:
                      ctrl.hasMore.value && !ctrl.isLoading.value
                          ? ctrl.fetchNextPage
                          : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: darkSlate,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.black12),
            SizedBox(height: 16),
            Text(
              'No order history found',
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
}