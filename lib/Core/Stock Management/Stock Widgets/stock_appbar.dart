// lib/Core/Stock Management/widgets/stock_appbar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/ongoining_shipment_page.dart';

import '../Stock Service & Damage/View/service_page.dart';
import '../stock_controller.dart';
import '../stock_shorlist_and_china_order.dart';

class StockAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isMobile;
  final ProductController controller;

  const StockAppBar({
    super.key,
    required this.isMobile,
    required this.controller,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + 1, // +1 for bottom border line
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: const Color(0xFF1E293B),
            size: isMobile ? 22 : 26,
          ),
          const SizedBox(width: 10),
          Text(
            'Inventory',
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      actions: isMobile ? _mobileActions() : _desktopActions(),
    );
  }

  List<Widget> _mobileActions() {
    return [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFF1E293B)),
        onSelected: (value) {
          if (value == 'shipments') Get.to(() => OnGoingShipmentsPage());
          if (value == 'service') Get.to(() => ServicePage());
          if (value == 'alerts') Get.to(() => ShortlistPage());
          if (value == 'refresh') controller.fetchProducts();
        },
        itemBuilder:
            (_) => const [
              PopupMenuItem(
                value: 'shipments',
                child: ListTile(
                  leading: Icon(Icons.local_shipping, color: Colors.orange),
                  title: Text('Shipments', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'service',
                child: ListTile(
                  leading: Icon(Icons.handyman, color: Colors.orange),
                  title: Text('Service Center', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'alerts',
                child: ListTile(
                  leading: Icon(Icons.warning_amber, color: Colors.red),
                  title: Text('Low Stock', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh, color: Colors.blue),
                  title: Text('Refresh', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
      ),
    ];
  }

  List<Widget> _desktopActions() {
    return [
      TextButton.icon(
        onPressed: () => Get.to(() => OnGoingShipmentsPage()),
        style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
        icon: const Icon(Icons.local_shipping, size: 20),
        label: const Text('Shipments', style: TextStyle(fontSize: 13)),
      ),
      TextButton.icon(
        onPressed: () => Get.to(() => ServicePage()),
        style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
        icon: const Icon(Icons.handyman_outlined, size: 20),
        label: const Text('Service Center', style: TextStyle(fontSize: 13)),
      ),
      const SizedBox(width: 8),
      TextButton.icon(
        onPressed: () => Get.to(() => ShortlistPage()),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFFEF2F2),
          foregroundColor: const Color(0xFFDC2626),
        ),
        icon: const Icon(Icons.warning_amber_rounded, size: 20),
        label: const Text('Alerts', style: TextStyle(fontSize: 13)),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
        tooltip: 'Refresh',
        onPressed: controller.fetchProducts,
      ),
      const SizedBox(width: 16),
    ];
  }
}