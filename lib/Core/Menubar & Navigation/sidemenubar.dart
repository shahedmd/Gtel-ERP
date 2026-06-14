import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import 'package:gtel_erp/Core/Utils/navigation_key.dart';
import 'package:gtel_erp/controller.dart';

import '../Auth/auth.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final String id;
  final List<MenuItem>? subItems;

  MenuItem({
    required this.title,
    required this.icon,
    required this.id,
    this.subItems,
  });
}

class NavigationController extends GetxController {
  var activeId = Routes.dailysales.obs;

  void changePage(String routeName) {
    if (activeId.value == routeName) return;
    activeId.value = routeName;
    Get.toNamed(routeName, id: NavKey.nestedHome);
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
                      ? SidebarMenu.activeAccent.withValues(alpha: 0.12)
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
  final NavigationController navCtrl = Get.find<NavigationController>();
  final RoleController rolecontroller = Get.find<RoleController>();

  static const Color sidebarBg = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);

  SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: sidebarBg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Obx(() {
              final isSuperAdmin = rolecontroller.isSuperAdmin;

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                physics: const BouncingScrollPhysics(),
                children: [
                  _NavTile(
                    id: Routes.liveorder,
                    title: "NEW ORDER",
                    icon: FontAwesomeIcons.moneyBill,
                  ),
                  if (isSuperAdmin)
                    _NavTile(
                      id: Routes.customeroverview,
                      title: "G TEL CUSTOMER",
                      icon: FontAwesomeIcons.user,
                      isSubItem: true,
                    ),
                  _NavTile(
                    id: Routes.debtor,
                    title: "DEBTOR/AGENT ACCOUNT",
                    icon: FontAwesomeIcons.userCheck,
                    isSubItem: true,
                  ),
                  _NavTile(
                    id: Routes.localpurchase,
                    title: "LOCAL PURCHASE",
                    icon: FontAwesomeIcons.productHunt,
                  ),
                  _NavTile(
                    id: Routes.purchase,
                    title: "LOCAL PURCHASE HISTORY",
                    icon: FontAwesomeIcons.productHunt,
                    isSubItem: true,
                  ),
                  if (isSuperAdmin)
                    _NavTile(
                      id: Routes.profitloss,
                      title: "SALE PROFIT & LOSS",
                      icon: FontAwesomeIcons.chartLine,
                      isSubItem: true,
                    ),
                  if (isSuperAdmin)
                    _NavTile(
                      id: Routes.overviewaccount,
                      icon: FontAwesomeIcons.chartPie,
                      title: "OVERVIEW DASHBOARD",
                    ),
                  if (isSuperAdmin)
                    _NavTile(
                      id: Routes.dashboard,
                      icon: FontAwesomeIcons.bookOpen,
                      title: "DAILY LEDGER",
                    ),
                  if (isSuperAdmin)
                    _NavTile(
                      id: Routes.cash,
                      icon: FontAwesomeIcons.cashRegister,
                      title: "CASH DRAWER",
                    ),
                  if (isSuperAdmin)
                    _NavTile(
                      id: Routes.vendor,
                      title: "G TEL VENDOR",
                      icon: FontAwesomeIcons.userTie,
                      isSubItem: true,
                    ),
                  _NavGroup(
                    title: "Expenses",
                    icon: FontAwesomeIcons.wallet,
                    children: [
                      _NavTile(
                        id: Routes.dailyexpenses,
                        title: "Daily Expenses",
                        isSubItem: true,
                      ),
                      if (isSuperAdmin)
                        _NavTile(
                          id: Routes.monthlyexpense,
                          title: "Monthly Expenses",
                          isSubItem: true,
                        ),
                    ],
                  ),
                  _NavGroup(
                    title: "Sales",
                    icon: FontAwesomeIcons.receipt,
                    children: [
                      _NavTile(
                        id: Routes.dailysales,
                        title: "Daily Sales",
                        isSubItem: true,
                      ),
                      if (isSuperAdmin)
                        _NavTile(
                          id: Routes.monthlysalespage,
                          title: "Monthly Sales",
                          isSubItem: true,
                        ),
                      _NavTile(
                        id: Routes.conditionpage,
                        title: "Condition Sale",
                        isSubItem: true,
                      ),
                      _NavTile(
                        id: Routes.salereturn,
                        title: "Sale Return",
                        isSubItem: true,
                      ),
                      if (isSuperAdmin)
                        _NavTile(
                          id: Routes.staffsalesreport,
                          title: "Staff Overview",
                          isSubItem: true,
                        ),
                      if (isSuperAdmin)
                        _NavTile(
                          id: Routes.productoverview,
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
                        id: Routes.stock,
                        title: "Stock Management",
                        isSubItem: true,
                      ),
                      _NavTile(
                        id: Routes.service,
                        title: "Service Product",
                        isSubItem: true,
                      ),
                      if (isSuperAdmin)
                        _NavTile(
                          id: Routes.shipment,
                          title: "Shipment Details",
                          isSubItem: true,
                        ),
                      if (isSuperAdmin)
                        _NavTile(
                          id: Routes.orderlist,
                          title: "China Order List",
                          isSubItem: true,
                        ),
                    ],
                  ),

                  // ── Staff & Admin Section ───────────────────────────────
                  if (isSuperAdmin) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: Divider(color: Colors.white10, thickness: 1),
                    ),
                    _NavTile(
                      id: Routes.staff,
                      icon: FontAwesomeIcons.userTie,
                      title: "Staff Members",
                    ),
                    // ── নতুন: Super Admin Panel ─────────────────────────
                    _NavTile(
                      id: Routes.superadmin,
                      icon: FontAwesomeIcons.userShield,
                      title: "Super Admin Panel",
                    ),
                  ],
                ],
              );
            }),
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
              color: activeAccent.withValues(alpha: 0.2),
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
    return Obx(() {
      final isSuperAdmin = rolecontroller.isSuperAdmin;
      final name = rolecontroller.currentUserName;
      final role = rolecontroller.currentUserRole.toUpperCase();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.black12,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          children: [
            // ── User Info ─────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      isSuperAdmin ? Colors.redAccent : activeAccent,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── নতুন: Logout Button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Get.back();
                            Get.find<AuthController>().logout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(
                  Icons.logout,
                  size: 16,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}