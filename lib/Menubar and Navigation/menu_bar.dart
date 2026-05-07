import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/navigation_key.dart';
import '../Authentication/auth_controller.dart';
import '../Permission/permission_controller.dart';
import 'app_pages.dart';

class NavigationController extends GetxController {
  final activeId = Routes.dailysales.obs;

  void changePage(String routeName) {
    if (activeId.value == routeName) return;

    activeId.value = routeName;
    Get.toNamed(routeName, id: NavKey.nestedHome);
  }
}

class SidebarMenu extends StatelessWidget {
  SidebarMenu({super.key});

  static const Color sidebarBg = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0x1AFFFFFF);

  final PermissionController permissionController =
      Get.find<PermissionController>();
  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: sidebarBg,
      child: Column(
        children: [
          const _SidebarHeader(),
          Expanded(
            child: Obx(() {
              if (permissionController.isLoading.value) {
                return const _MenuLoading();
              }

              final items = _visibleMenuItems();

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: items.length,
                separatorBuilder: (_, index) {
                  return items[index] is _MenuDivider
                      ? const SizedBox.shrink()
                      : const SizedBox(height: 2);
                },
                itemBuilder: (context, index) {
                  final item = items[index];

                  if (item is _MenuDivider) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Divider(height: 1, color: divider),
                    );
                  }

                  if (item is _MenuGroup) {
                    return item;
                  }

                  if (item is _MenuTile) {
                    return item;
                  }

                  return const SizedBox.shrink();
                },
              );
            }),
          ),
          _SidebarFooter(
            permissionController: permissionController,
            authController: authController,
          ),
        ],
      ),
    );
  }

  List<Widget> _visibleMenuItems() {
    final items = <Widget>[];

    void addTile({
      required String route,
      required String title,
      required IconData icon,
      bool isImportant = false,
    }) {
      if (permissionController.canView(route)) {
        items.add(
          _MenuTile(
            route: route,
            title: title,
            icon: icon,
            isImportant: isImportant,
          ),
        );
      }
    }

    List<_MenuTile> groupTiles(List<_MenuTile> tiles) {
      return tiles.where((tile) {
        return permissionController.canView(tile.route);
      }).toList();
    }

    addTile(
      route: Routes.liveorder,
      title: 'New Order',
      icon: FontAwesomeIcons.moneyBill,
      isImportant: true,
    );

    addTile(
      route: Routes.debtor,
      title: 'Debtor / Agent',
      icon: FontAwesomeIcons.userCheck,
    );

    addTile(
      route: Routes.localpurchase,
      title: 'Local Purchase',
      icon: FontAwesomeIcons.cartShopping,
    );

    addTile(
      route: Routes.purchase,
      title: 'Purchase History',
      icon: FontAwesomeIcons.clockRotateLeft,
    );

    final salesItems = groupTiles([
      const _MenuTile(
        route: Routes.dailysales,
        title: 'Daily Sales',
        icon: FontAwesomeIcons.receipt,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.monthlysalespage,
        title: 'Monthly Sales',
        icon: FontAwesomeIcons.calendarDays,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.conditionpage,
        title: 'Condition Sale',
        icon: FontAwesomeIcons.handHoldingDollar,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.salereturn,
        title: 'Sale Return',
        icon: FontAwesomeIcons.rotateLeft,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.staffsalesreport,
        title: 'Staff Sales Report',
        icon: FontAwesomeIcons.chartColumn,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.productoverview,
        title: 'Product Analytics',
        icon: FontAwesomeIcons.chartSimple,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.customeroverview,
        title: 'Customer Analytics',
        icon: FontAwesomeIcons.users,
        isSubItem: true,
      ),
    ]);

    if (salesItems.isNotEmpty) {
      items.add(
        _MenuGroup(
          title: 'Sales',
          icon: FontAwesomeIcons.receipt,
          children: salesItems,
        ),
      );
    }

    final stockItems = groupTiles([
      const _MenuTile(
        route: Routes.stock,
        title: 'Stock Management',
        icon: FontAwesomeIcons.boxesStacked,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.service,
        title: 'Service Product',
        icon: FontAwesomeIcons.screwdriverWrench,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.shipment,
        title: 'Shipment',
        icon: FontAwesomeIcons.truckFast,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.orderlist,
        title: 'China Order List',
        icon: FontAwesomeIcons.listCheck,
        isSubItem: true,
      ),
    ]);

    if (stockItems.isNotEmpty) {
      items.add(
        _MenuGroup(
          title: 'Products & Stock',
          icon: FontAwesomeIcons.boxesStacked,
          children: stockItems,
        ),
      );
    }

    final financeItems = groupTiles([
      const _MenuTile(
        route: Routes.dashboard,
        title: 'Daily Ledger',
        icon: FontAwesomeIcons.bookOpen,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.cash,
        title: 'Cash Drawer',
        icon: FontAwesomeIcons.cashRegister,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.profitloss,
        title: 'Profit & Loss',
        icon: FontAwesomeIcons.chartLine,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.overviewaccount,
        title: 'Account Overview',
        icon: FontAwesomeIcons.chartPie,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.vendor,
        title: 'Vendor',
        icon: FontAwesomeIcons.userTie,
        isSubItem: true,
      ),
    ]);

    if (financeItems.isNotEmpty) {
      items.add(
        _MenuGroup(
          title: 'Finance',
          icon: FontAwesomeIcons.wallet,
          children: financeItems,
        ),
      );
    }

    final expenseItems = groupTiles([
      const _MenuTile(
        route: Routes.dailyexpenses,
        title: 'Daily Expenses',
        icon: FontAwesomeIcons.fileInvoiceDollar,
        isSubItem: true,
      ),
      const _MenuTile(
        route: Routes.monthlyexpense,
        title: 'Monthly Expenses',
        icon: FontAwesomeIcons.calendarCheck,
        isSubItem: true,
      ),
    ]);

    if (expenseItems.isNotEmpty) {
      items.add(
        _MenuGroup(
          title: 'Expenses',
          icon: FontAwesomeIcons.wallet,
          children: expenseItems,
        ),
      );
    }

    final peopleItems = groupTiles([
      const _MenuTile(
        route: Routes.staff,
        title: 'Staff Members',
        icon: FontAwesomeIcons.userTie,
        isSubItem: true,
      ),
    ]);

    if (peopleItems.isNotEmpty) {
      items.add(
        _MenuGroup(
          title: 'People',
          icon: FontAwesomeIcons.usersGear,
          children: peopleItems,
        ),
      );
    }

    if (permissionController.isSuperAdmin) {
      items.add(const _MenuDivider());
      items.add(
        const _MenuTile(
          route: Routes.superadmin,
          title: 'Super Admin',
          icon: FontAwesomeIcons.userShield,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(const _EmptyMenuState());
    }

    return items;
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SidebarMenu.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SidebarMenu.activeAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'G-Tel ERP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SidebarMenu.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String route;
  final String title;
  final IconData icon;
  final bool isSubItem;
  final bool isImportant;

  const _MenuTile({
    required this.route,
    required this.title,
    required this.icon,
    this.isSubItem = false,
    this.isImportant = false,
  });

  @override
  Widget build(BuildContext context) {
    final navController = Get.find<NavigationController>();

    return Obx(() {
      final isActive = navController.activeId.value == route;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => navController.changePage(route),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 42,
            padding: EdgeInsets.only(
              left: isSubItem ? 18 : 12,
              right: 10,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? SidebarMenu.activeAccent.withOpacity(0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? SidebarMenu.activeAccent.withOpacity(0.28)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  icon,
                  size: isSubItem ? 14 : 15,
                  color: isActive
                      ? SidebarMenu.textPrimary
                      : isImportant
                          ? const Color(0xFFBFDBFE)
                          : SidebarMenu.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? SidebarMenu.textPrimary
                          : SidebarMenu.textSecondary,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: SidebarMenu.activeAccent,
                      borderRadius: BorderRadius.circular(99),
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

class _MenuGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_MenuTile> children;

  const _MenuGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.white.withOpacity(0.04),
        highlightColor: Colors.white.withOpacity(0.04),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
        collapsedIconColor: SidebarMenu.textSecondary,
        iconColor: SidebarMenu.textSecondary,
        leading: FaIcon(
          icon,
          size: 15,
          color: SidebarMenu.textSecondary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: SidebarMenu.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        children: children,
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final PermissionController permissionController;
  final AuthController authController;

  const _SidebarFooter({
    required this.permissionController,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = permissionController.currentUser.value;
      final badgeColor = permissionController.roleBadgeColor;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Color(0x33000000),
          border: Border(top: BorderSide(color: SidebarMenu.divider)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: badgeColor,
              child: Text(
                user?.displayName.isNotEmpty == true
                    ? user!.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Loading...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SidebarMenu.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    permissionController.roleDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: authController.logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 21,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MenuLoading extends StatelessWidget {
  const _MenuLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.3,
          color: SidebarMenu.activeAccent,
        ),
      ),
    );
  }
}

class _EmptyMenuState extends StatelessWidget {
  const _EmptyMenuState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        'No pages available for this account.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: SidebarMenu.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}