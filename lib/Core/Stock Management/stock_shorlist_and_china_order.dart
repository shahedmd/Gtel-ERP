
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:gtel_erp/Shipment/controller.dart';

import 'China Orderlist Widgets/order_cart_dialog.dart';
import 'China Orderlist Widgets/shortlist_appbar.dart';
import 'China Orderlist Widgets/shortlist_table.dart';
import 'stockcontroller.dart';

// ─────────────────────────────────────────────────────────────
// OrderCartItem — cart-এর single item
// ─────────────────────────────────────────────────────────────
class OrderCartItem {
  final dynamic product;
  int qty;
  OrderCartItem({required this.product, required this.qty});
}

// ─────────────────────────────────────────────────────────────
// OrderCartController — cart state
// ─────────────────────────────────────────────────────────────
class OrderCartController extends GetxController {
  final cartItems = <OrderCartItem>[].obs;
  final companyName = ''.obs;
  final deliveryMethod = 'Sea'.obs;

  void addToCart(dynamic product, int qty) {
    final existing = cartItems.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existing != null) {
      existing.qty += qty;
      cartItems.refresh();
    } else {
      cartItems.add(OrderCartItem(product: product, qty: qty));
    }
  }

  void updateQty(dynamic product, int newQty) {
    if (newQty <= 0) return;
    final existing = cartItems.firstWhereOrNull(
      (item) => item.product.id == product.id,
    );
    if (existing != null) {
      existing.qty = newQty;
      cartItems.refresh();
    }
  }

  void removeFromCart(dynamic product) {
    cartItems.removeWhere((item) => item.product.id == product.id);
  }

  void clearCart() {
    cartItems.clear();
    companyName.value = '';
    deliveryMethod.value = 'Sea';
  }
}

// ─────────────────────────────────────────────────────────────
// ScrollBehavior — mouse + touch
// ─────────────────────────────────────────────────────────────
class ShortlistScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

// ─────────────────────────────────────────────────────────────
// ShortlistPage — main page
// ─────────────────────────────────────────────────────────────
class ShortlistPage extends StatefulWidget {
  const ShortlistPage({super.key});

  @override
  State<ShortlistPage> createState() => _ShortlistPageState();
}

class _ShortlistPageState extends State<ShortlistPage> {
  final ProductController _ctrl = Get.find<ProductController>();
  final ShipmentController _shipCtrl = Get.find<ShipmentController>();
  final OrderCartController _cartCtrl = Get.put(OrderCartController());
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: _ctrl.shortlistSearchText.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.shortlistSearchText.value.isEmpty) {
        _ctrl.fetchShortList(page: 1);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ShortlistAppBar(
        isMobile: isMobile,
        cartController: _cartCtrl,
        controller: _ctrl,
        onShowCart: () => _showCart(context),
      ),
      body: ScrollConfiguration(
        behavior: ShortlistScrollBehavior(),
        child: Column(
          children: [
            // Stats
            _StatsSection(isMobile: isMobile, ctrl: _ctrl),

            // Search bar
            _SearchBar(
              isMobile: isMobile,
              searchCtrl: _searchCtrl,
              ctrl: _ctrl,
            ),

            // Table
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 20,
                  0,
                  isMobile ? 12 : 20,
                  20,
                ),
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
                    // Header + refresh
                    _TableHeader(ctrl: _ctrl),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Data
                    Expanded(
                      child: ShortlistTable(
                        isMobile: isMobile,
                        ctrl: _ctrl,
                        shipCtrl: _shipCtrl,
                        cartCtrl: _cartCtrl,
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Pagination
                    _PaginationFooter(isMobile: isMobile, ctrl: _ctrl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCart(BuildContext context) {
    showOrderCartDialog(context: context, cartCtrl: _cartCtrl);
  }
}

// ─────────────────────────────────────────────────────────────
// Stats Section
// ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  final bool isMobile;
  final ProductController ctrl;

  const _StatsSection({required this.isMobile, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
      child: Obx(() {
        final total = ctrl.shortlistTotal.value;

        final restockCard = Expanded(
          child: _StatCard(
            title: 'Products Needing Restock',
            value: total.toString(),
            icon: Icons.priority_high_rounded,
            bgColor: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFEA580C),
            borderColor: const Color(0xFFFED7AA),
          ),
        );

        final actionCard = Expanded(
          child: _StatCard(
            title: 'Recommended Action',
            value: 'Generate PO',
            icon: Icons.assignment_turned_in,
            bgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            borderColor: const Color(0xFFBFDBFE),
            isText: true,
          ),
        );

        return isMobile
            ? Column(
              children: [
                Row(children: [restockCard]),
                const SizedBox(height: 12),
                Row(children: [actionCard]),
              ],
            )
            : Row(
              children: [restockCard, const SizedBox(width: 16), actionCard],
            );
      }),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color borderColor;
  final bool isText;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.borderColor,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isText ? 18 : 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final bool isMobile;
  final TextEditingController searchCtrl;
  final ProductController ctrl;

  const _SearchBar({
    required this.isMobile,
    required this.searchCtrl,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 8,
      ).copyWith(bottom: 16),
      child: TextField(
        controller: searchCtrl,
        onChanged: ctrl.searchShortlist,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search shortlist by model or product name...',
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
            onPressed: () {
              searchCtrl.clear();
              ctrl.searchShortlist('');
            },
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Table Header
// ─────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final ProductController ctrl;

  const _TableHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Low Stock Inventory',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () => ctrl.fetchShortList(page: 1),
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
  final ProductController ctrl;

  const _PaginationFooter({required this.isMobile, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = ctrl.shortlistTotal.value;
      final current = ctrl.shortlistPage.value;
      final size = ctrl.shortlistLimit.value;
      final totalPages = size > 0 ? (total / size).ceil() : 0;
      final start = total == 0 ? 0 : ((current - 1) * size) + 1;
      final end = (current * size) > total ? total : (current * size);

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isMobile)
              Text(
                'Showing $start–$end of $total alerts',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              )
            else
              Text(
                '$total alerts',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      current > 1 ? () => ctrl.prevShortlistPage() : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Page $current / $totalPages',
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
                          ? () => ctrl.nextShortlistPage()
                          : null,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}