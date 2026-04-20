// lib/Core/Menubar & Navigation/sidemenubar.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Auth/auth.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import 'package:gtel_erp/Core/Core%20Utils/navigation_key.dart';

import '../Permission/permission_controller.dart';

// ─────────────────────────────────────────────────────────────
// NavigationController — page change handle করে
// ─────────────────────────────────────────────────────────────
class NavigationController extends GetxController {
  var activeId = Routes.dailysales.obs;

  void changePage(String routeName) {
    if (activeId.value == routeName) return;
    activeId.value = routeName;
    Get.toNamed(routeName, id: NavKey.nestedHome);
  }
}

// ─────────────────────────────────────────────────────────────
// _NavGroup — collapsible menu group (Expenses, Sales, etc.)
// ─────────────────────────────────────────────────────────────
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
    // children-এর মধ্যে যদি কোনো visible item না থাকে তাহলে group-ই দেখাবে না
    if (children.isEmpty) return const SizedBox.shrink();

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

// ─────────────────────────────────────────────────────────────
// _NavTile — single menu item
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// SidebarMenu — main sidebar widget
// ─────────────────────────────────────────────────────────────
class SidebarMenu extends StatelessWidget {
  static const Color sidebarBg = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);

  SidebarMenu({super.key});

  final PermissionController _permCtrl = Get.find<PermissionController>();
  final AuthController _authCtrl = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: sidebarBg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMenuList()),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
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

  // ── Menu List ────────────────────────────────────────────────
  // Obx একটাই — পুরো list একসাথে rebuild হবে
  Widget _buildMenuList() {
    return Obx(() {
      // permission check এখানে একবারই করবো
      final bool isSuperAdmin = _permCtrl.isSuperAdmin;
      final bool isAdmin = _permCtrl.isAdmin;

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Live Order — সবাই দেখতে পাবে ──
          const _NavTile(
            id: Routes.liveorder,
            title: "NEW ORDER",
            icon: FontAwesomeIcons.moneyBill,
          ),

          // ── Customer — admin+ ──
          if (isAdmin)
            const _NavTile(
              id: Routes.customeroverview,
              title: "G TEL CUSTOMER",
              icon: FontAwesomeIcons.user,
              isSubItem: true,
            ),

          // ── Debtor — সবাই ──
          const _NavTile(
            id: Routes.debtor,
            title: "DEBTOR/AGENT ACCOUNT",
            icon: FontAwesomeIcons.userCheck,
            isSubItem: true,
          ),

          // ── Local Purchase — সবাই ──
          const _NavTile(
            id: Routes.localpurchase,
            title: "LOCAL PURCHASE",
            icon: FontAwesomeIcons.productHunt,
          ),

          const _NavTile(
            id: Routes.purchase,
            title: "LOCAL PURCHASE HISTORY",
            icon: FontAwesomeIcons.productHunt,
            isSubItem: true,
          ),

          // ── Profit/Loss — superadmin only ──
          if (isSuperAdmin)
            const _NavTile(
              id: Routes.profitloss,
              title: "SALE PROFIT & LOSS",
              icon: FontAwesomeIcons.chartLine,
              isSubItem: true,
            ),

          // ── Overview Dashboard — superadmin only ──
          if (isSuperAdmin)
            const _NavTile(
              id: Routes.overviewaccount,
              icon: FontAwesomeIcons.chartPie,
              title: "OVERVIEW DASHBOARD",
            ),

          // ── Daily Ledger — superadmin only ──
          if (isSuperAdmin)
            const _NavTile(
              id: Routes.dashboard,
              icon: FontAwesomeIcons.bookOpen,
              title: "DAILY LEDGER",
            ),

          // ── Cash Drawer — superadmin only ──
          if (isSuperAdmin)
            const _NavTile(
              id: Routes.cash,
              icon: FontAwesomeIcons.cashRegister,
              title: "CASH DRAWER",
            ),

          // ── Vendor — superadmin only ──
          if (isSuperAdmin)
            const _NavTile(
              id: Routes.vendor,
              title: "G TEL VENDOR",
              icon: FontAwesomeIcons.userTie,
              isSubItem: true,
            ),

          // ── Expenses Group ──
          _NavGroup(
            title: "Expenses",
            icon: FontAwesomeIcons.wallet,
            children: [
              const _NavTile(
                id: Routes.dailyexpenses,
                title: "Daily Expenses",
                isSubItem: true,
              ),
              if (isSuperAdmin)
                const _NavTile(
                  id: Routes.monthlyexpense,
                  title: "Monthly Expenses",
                  isSubItem: true,
                ),
            ],
          ),

          // ── Sales Group ──
          _NavGroup(
            title: "Sales",
            icon: FontAwesomeIcons.receipt,
            children: [
              const _NavTile(
                id: Routes.dailysales,
                title: "Daily Sales",
                isSubItem: true,
              ),
              if (isSuperAdmin)
                const _NavTile(
                  id: Routes.monthlysalespage,
                  title: "Monthly Sales",
                  isSubItem: true,
                ),
              const _NavTile(
                id: Routes.conditionpage,
                title: "Condition Sale",
                isSubItem: true,
              ),
              const _NavTile(
                id: Routes.salereturn,
                title: "Sale Return",
                isSubItem: true,
              ),
              if (isSuperAdmin)
                const _NavTile(
                  id: Routes.staffsalesreport,
                  title: "Staff Overview",
                  isSubItem: true,
                ),
              if (isSuperAdmin)
                const _NavTile(
                  id: Routes.productoverview,
                  title: "Product Overview",
                  isSubItem: true,
                ),
            ],
          ),

          // ── Products & Stock Group ──
          _NavGroup(
            title: "Products & Stock",
            icon: FontAwesomeIcons.boxesStacked,
            children: [
              const _NavTile(
                id: Routes.stock,
                title: "Stock Management",
                isSubItem: true,
              ),
              const _NavTile(
                id: Routes.service,
                title: "Service Product",
                isSubItem: true,
              ),
              if (isSuperAdmin)
                const _NavTile(
                  id: Routes.shipment,
                  title: "Shipment Details",
                  isSubItem: true,
                ),
              if (isSuperAdmin)
                const _NavTile(
                  id: Routes.orderlist,
                  title: "China Order List",
                  isSubItem: true,
                ),
            ],
          ),

          // ── Staff — superadmin only ──
          if (isSuperAdmin) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Divider(color: Colors.white10, thickness: 1),
            ),
            const _NavTile(
              id: Routes.staff,
              icon: FontAwesomeIcons.userTie,
              title: "Staff Members",
            ),
          ],
          // Staff section-এর পরে
          if (isSuperAdmin) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Divider(color: Colors.white10),
            ),
            const _NavTile(
              id: Routes.superadmin,
              icon: FontAwesomeIcons.userShield,
              title: "SuperAdmin Panel",
            ),
          ],
        ],
      );
    });
  }

  // ── Footer — user info + logout ─────────────────────────────
  Widget _buildFooter() {
    return Obx(() {
      final user = _permCtrl.currentUser.value;
      final Color badgeColor = _permCtrl.roleBadgeColor;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.black12,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            // Avatar with role color
            CircleAvatar(
              radius: 18,
              backgroundColor: badgeColor,
              child: Text(
                // নাম-এর প্রথম অক্ষর দেখাবে
                (user?.displayName.isNotEmpty == true)
                    ? user!.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real display name
                  Text(
                    user?.displayName ?? 'Loading...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Role badge
                  Text(
                    _permCtrl.roleDisplayName,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Logout button
            IconButton(
              onPressed: _authCtrl.logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              tooltip: "Logout",
            ),
          ],
        ),
      );
    });
  }
}
