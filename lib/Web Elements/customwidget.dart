// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import 'route.dart';

// menu_item_model.dart

class MenuItem {
  final String title;
  final IconData icon;
  final String id; // Unique ID for routing/tracking
  final List<MenuItem>? subItems;

  MenuItem({
    required this.title,
    required this.icon,
    required this.id,
    this.subItems,
  });
}

class NavigationController extends GetxController {
  var activeId = Routes.DASHBOARD.obs;

  void changePage(String routeName) {
    if (activeId.value == routeName) {
      return; // Don't reload if already on the page
    }

    activeId.value = routeName;

    // id: 1 refers to the Get.nestedKey(1) we set in MainLayout
    Get.toNamed(routeName, id: 1);
  }
}

class _NavGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _NavGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      // This removes the ugly default borders/dividers from ExpansionTile
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
        leading: FaIcon(icon, size: 16, color: SidebarMenu.textSecondary),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_down,
          color: SidebarMenu.textSecondary,
          size: 18,
        ),
        children: children,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String id;
  final String title;
  final IconData? icon;
  final bool isSubItem;

  const _NavTile({
    required this.id,
    required this.title,
    this.icon,
    this.isSubItem = false,
  });

  @override
  Widget build(BuildContext context) {
    final navCtrl = Get.find<NavigationController>();

    return Obx(() {
      final bool isActive = navCtrl.activeId.value == id;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: InkWell(
          onTap: () => navCtrl.changePage(id),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isSubItem ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? SidebarMenu.activeAccent.withOpacity(0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  FaIcon(
                    icon,
                    size: 16,
                    color:
                        isActive
                            ? SidebarMenu.activeAccent
                            : SidebarMenu.textSecondary,
                  ),
                  const SizedBox(width: 15),
                ] else if (isSubItem) ...[
                  // Dot indicator for nested items
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 6 : 4,
                    height: isActive ? 6 : 4,
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? SidebarMenu.activeAccent
                              : SidebarMenu.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color:
                          isActive ? Colors.white : SidebarMenu.textSecondary,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isActive && !isSubItem)
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: SidebarMenu.activeAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class SidebarMenu extends StatelessWidget {
  // Access the controller we initialized in MainLayout
  final NavigationController navCtrl = Get.find<NavigationController>();

  // Professional Theme Colors
  static const Color sidebarBg = Color(0xFF111827); // Modern Dark Slate
  static const Color activeAccent = Color(0xFF3B82F6); // Electric Blue
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF); // Muted Gray

  SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260, // Fixed width for Desktop stability
      color: sidebarBg,
      child: Column(
        children: [
          _buildHeader(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              physics: const BouncingScrollPhysics(),
              children: [
                _NavTile(
                  id: Routes.OVERVIEWACCOUNT,
                  icon: FontAwesomeIcons.chartPie,
                  title: "Overview Dashboard",
                ),
                // --- DASHBOARD ---
                _NavTile(
                  id: Routes.DASHBOARD,
                  icon: FontAwesomeIcons.chartPie,
                  title: "Daily Ledger",
                ),
                _NavTile(
                  id: Routes.LIVEORDER,
                  title: "Live Order",
                  icon: FontAwesomeIcons.moneyBill,

                  isSubItem: false,
                ),
                // --- FINANCE ---
                _NavGroup(
                  title: "Finance",
                  icon: FontAwesomeIcons.moneyBillTransfer,
                  children: [
                    _NavTile(
                      id: Routes.DEBTOR,
                      title: "Debtor Account",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.VENDOR,
                      title: "Vendor Account",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: '/cash', // Example of a standalone route
                      icon: FontAwesomeIcons.cashRegister,
                      title: "Cash Drawer",
                    ),
                  ],
                ),

                // --- EXPENSES ---
                _NavGroup(
                  title: "Expenses",
                  icon: FontAwesomeIcons.wallet,
                  children: [
                    _NavTile(
                      id: Routes.DAILY_EXPENSES,
                      title: "Daily Expenses",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.MONTHLY_EXPENSES,
                      title: "Monthly Expenses",
                      isSubItem: true,
                    ),
                  ],
                ),

                // --- SALES ---
                _NavGroup(
                  title: "Sales",
                  icon: FontAwesomeIcons.receipt,
                  children: [
                    _NavTile(
                      id: Routes.DAILY_SALES,
                      title: "Daily Sales",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.MONTHLY_SALES,
                      title: "Monthly Sales",
                      isSubItem: true,
                    ),

                    _NavTile(
                      id: Routes.CONDITION,
                      title: "Condition Sale",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.SALERETURN,
                      title: "Sale Return",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: '/profit',
                      title: "Sale Overview",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.CUSTOMEROVERVIEW,
                      title: "Customer Overview",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.STAFFSALEREPORT,
                      title: "Staff Overview",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: Routes.PRODUCTOVERVIEW,
                      title: "Product Overview",
                      isSubItem: true,
                    ),
                  ],
                ),

                _NavGroup(
                  title: "Products & Stock",
                  icon: FontAwesomeIcons.boxesStacked,
                  children: [
                    _NavTile(
                      id: Routes.STOCK,
                      title: "Stock Management",
                      isSubItem: true,
                    ),
                    _NavTile(
                      id: '/service', // Example of a standalone route
                      icon: FontAwesomeIcons.productHunt,
                      title: "Service Product",
                    ),
                    _NavTile(
                      id: Routes.SHIPMENT,
                      icon: FontAwesomeIcons.shippingFast,
                      title: "Shipment Details",
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Divider(color: Colors.white10, thickness: 1),
                ),

                // --- STAFF ---
                _NavTile(
                  id: Routes.STAFF,
                  icon: FontAwesomeIcons.userTie,
                  title: "Staff Members",
                ),
              ],
            ),
          ),

          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activeAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              FontAwesomeIcons.bolt,
              color: activeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          const Text(
            "G Tel ERP",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.black12,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: activeAccent,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Admin Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "v1.0.24",
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
