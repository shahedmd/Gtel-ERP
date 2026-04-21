// lib/Core/Stock Management/widgets/order_history_table.dart
// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import '../../Core Utils/activity_logger.dart';
import '../../Permission/permission_button.dart';
import '../../Permission/permission_controller.dart';
import '../china_order_list.dart';
import 'order_history_dialog.dart';

class OrderHistoryTable extends StatelessWidget {
  final bool isMobile;
  final OrderHistoryController ctrl;

  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  OrderHistoryTable({
    super.key,
    required this.isMobile,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return isMobile
        ? _MobileCards(ctrl: ctrl)
        : _DesktopTable(ctrl: ctrl, vScroll: _vScroll, hScroll: _hScroll);
  }
}

// ─────────────────────────────────────────────────────────────
// Desktop Table
// ─────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final OrderHistoryController ctrl;
  final ScrollController vScroll;
  final ScrollController hScroll;

  const _DesktopTable({
    required this.ctrl,
    required this.vScroll,
    required this.hScroll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 950 ? constraints.maxWidth : 950.0;

        return ScrollConfiguration(
          behavior: TableScrollBehavior(),
          child: Scrollbar(
            controller: vScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: vScroll,
              child: Scrollbar(
                controller: hScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: hScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          color: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          child: const Row(
                            children: [
                              _HeaderCell('S/N', 60),
                              _HeaderCell('DATE', 160),
                              _HeaderCell('COMPANY NAME', 250),
                              _HeaderCell('VIA', 80),
                              _HeaderCell('ITEMS', 80),
                              _HeaderCell('STATUS', 120),
                              _HeaderCell('ACTION', 100),
                            ],
                          ),
                        ),
                        // Rows — Obx একটাই এখানে
                        Obx(() => ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ctrl.orders.length,
                              itemBuilder: (context, index) {
                                final doc = ctrl.orders[index];
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final serial =
                                    ((ctrl.pageStartDocs.length - 1) *
                                            OrderHistoryController.pageSize) +
                                        index +
                                        1;
                                return _DesktopRow(
                                  doc: doc,
                                  data: data,
                                  serial: serial,
                                  ctrl: ctrl,
                                );
                              },
                            )),
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
}

// ─────────────────────────────────────────────────────────────
// Desktop Row
// ─────────────────────────────────────────────────────────────
class _DesktopRow extends StatelessWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;
  final int serial;
  final OrderHistoryController ctrl;

  const _DesktopRow({
    required this.doc,
    required this.data,
    required this.serial,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(data['date']);
    final status = data['status'] ?? 'Pending';

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          _DataCell(
            Text('$serial',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: textDark)),
            60,
          ),
          _DataCell(
            Text(dateStr,
                style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            160,
          ),
          _DataCell(
            Text(data['company_name'] ?? 'N/A',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: darkSlate,
                    fontSize: 14)),
            250,
          ),
          _DataCell(
            Text(data['delivery_method'] ?? 'N/A',
                style: const TextStyle(color: textDark)),
            80,
          ),
          _DataCell(
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${data['total_items'] ?? 0}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: activeAccent),
              ),
            ),
            80,
          ),
          _DataCell(OrderStatusBadge(status: status), 120),
          _DataCell(
            _ActionMenu(docId: doc.id, status: status, ctrl: ctrl),
            100,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mobile Cards
// ─────────────────────────────────────────────────────────────
class _MobileCards extends StatelessWidget {
  final OrderHistoryController ctrl;

  const _MobileCards({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: ctrl.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = ctrl.orders[index];
            final data = doc.data() as Map<String, dynamic>;
            final dateStr = _formatDate(data['date']);
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
                  // Card header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
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
                        _ActionMenu(
                            docId: doc.id,
                            status: status,
                            ctrl: ctrl),
                      ],
                    ),
                  ),

                  // Card body
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600)),
                            OrderStatusBadge(status: status),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Via',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey)),
                                Text(
                                  data['delivery_method'] ?? 'N/A',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                const Text('Total Items',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey)),
                                Text(
                                  '${data['total_items'] ?? 0} Models',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: activeAccent),
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
        ));
  }
}

// ─────────────────────────────────────────────────────────────
// Action Menu — permission check সহ
// ─────────────────────────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final String docId;
  final String status;
  final OrderHistoryController ctrl;

  const _ActionMenu({
    required this.docId,
    required this.status,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) => _handleAction(context, value),
      itemBuilder: (_) => [
        // View/Edit — canView permission
        const PopupMenuItem(
          value: 'view',
          child: Row(children: [
            Icon(Icons.visibility, color: activeAccent, size: 20),
            SizedBox(width: 10),
            Text('View / Edit'),
          ]),
        ),

        // Change Status — canEdit permission
        const PopupMenuItem(
          value: 'status',
          child: Row(children: [
            Icon(Icons.sync_alt, color: Colors.orange, size: 20),
            SizedBox(width: 10),
            Text('Change Status'),
          ]),
        ),

        // Delete — canDelete permission
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 20),
            SizedBox(width: 10),
            Text('Delete Order',
                style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, String value) {
    switch (value) {
      case 'view':
        showOrderDetailDialog(
          context: context,
          docId: docId,
          ctrl: ctrl,
        );
        break;
      case 'status':
        _changeStatusDialog(context);
        break;
      case 'delete':
        _deleteOrderDialog(context);
        break;
    }
  }

  void _changeStatusDialog(BuildContext context) {
    // canEdit permission check
    final permOk = _checkPermission(PermissionType.canEdit);
    if (!permOk) {
      Get.snackbar('Permission Denied',
          'You don\'t have permission to change status',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final selectedStatus = status.obs;

    Get.dialog(AlertDialog(
      title: const Text('Update Order Status'),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Obx(() => DropdownButtonFormField<String>(
            value: selectedStatus.value,
            decoration:
                const InputDecoration(border: OutlineInputBorder()),
            items: ['Pending', 'On the way', 'Complete']
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) selectedStatus.value = val;
            },
          )),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Get.back();
            await ctrl.updateOrderStatus(docId, selectedStatus.value);
            await ActivityLogger.log(
              action: 'UPDATE_ORDER_STATUS',
              module: 'Stock',
              details:
                  'Order $docId → ${selectedStatus.value}',
            );
            Get.snackbar(
              'Success',
              'Status changed to ${selectedStatus.value}',
              backgroundColor: Colors.green,
              colorText: Colors.white,
            );
          },
          child: const Text('Update'),
        ),
      ],
    ));
  }

  void _deleteOrderDialog(BuildContext context) {
    // canDelete permission check
    final permOk = _checkPermission(PermissionType.canDelete);
    if (!permOk) {
      Get.snackbar('Permission Denied',
          'You don\'t have permission to delete orders',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    Get.defaultDialog(
      title: 'Delete Entire Order?',
      middleText: 'This action cannot be undone. Are you sure?',
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: darkSlate,
      onConfirm: () async {
        Get.back();
        await ctrl.deleteOrder(docId);
        await ActivityLogger.log(
          action: 'DELETE_ORDER',
          module: 'Stock',
          details: 'Purchase order $docId deleted',
        );
        Get.snackbar('Deleted', 'Purchase order deleted.',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white);
      },
    );
  }

  bool _checkPermission(PermissionType type) {
    try {
      from(PermissionController ctrl) {
        switch (type) {
          case PermissionType.canEdit:
            return ctrl.canEdit(Routes.orderlist);
          case PermissionType.canDelete:
            return ctrl.canDelete(Routes.orderlist);
          default:
            return ctrl.canView(Routes.orderlist);
        }
      }

      if (Get.isRegistered<PermissionController>()) {
        return from(Get.find<PermissionController>());
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Shared UI widgets
// ─────────────────────────────────────────────────────────────
class OrderStatusBadge extends StatelessWidget {
  final String status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
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
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;

  const _HeaderCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
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
}

class _DataCell extends StatelessWidget {
  final Widget child;
  final double width;

  const _DataCell(this.child, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
String _formatDate(dynamic timestamp) {
  if (timestamp == null) return 'N/A';
  try {
    return DateFormat('dd MMM yyyy, hh:mm a')
        .format((timestamp as Timestamp).toDate());
  } catch (_) {
    return 'N/A';
  }
}