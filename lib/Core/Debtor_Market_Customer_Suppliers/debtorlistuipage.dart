// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/createdebtordialog.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordetails_transactionlist.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordartmodel.dart';
import 'package:intl/intl.dart';
import '../../Permission/permission_button.dart';
import '../../Permission/permission_controller.dart';
import '../../controller.dart';
import '../../Web Screen/Sales/controller.dart';

// --- ERP COLOR PALETTE ---
const Color primaryColor = Color(0xFF2563EB);
const Color scaffoldBg = Color(0xFFF8FAFC);
const Color surfaceWhite = Colors.white;
const Color textDark = Color(0xFF0F172A);
const Color textLight = Color(0xFF64748B);
const Color borderCol = Color(0xFFE2E8F0);
const Color successGreen = Color(0xFF16A34A);
const Color dangerRed = Color(0xFFDC2626);
const Color wholesaleColor = Color(0xFF7C3AED); // purple
const Color vipColor = Color(0xFFCA8A04); // gold/amber

// ==========================================
// CATEGORY FILTER
// ==========================================
enum DebtorCategoryFilter { all, agent, wholesale, vip }

class DebtorPageController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final Rx<DebtorCategoryFilter> categoryFilter = DebtorCategoryFilter.all.obs;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}

class Debatorpage extends StatelessWidget {
  Debatorpage({super.key});

  final DebatorController controller = Get.put(DebatorController());
  final DebtorPageController pageCtrl = Get.put(DebtorPageController());

  final ScrollController _hScroll = ScrollController();

  final NumberFormat bdCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '৳',
    decimalDigits: 2,
  );

  // Category color/label helper — used by badges, avatars, and chips.
  Color _categoryColor(DebtorModel d) {
    if (d.isAgent) return primaryColor;
    final cat = (d.customerCategory ?? '').toUpperCase();
    if (cat == 'VIP') return vipColor;
    return wholesaleColor; // default regular-customer color
  }

  String _categoryLabel(DebtorModel d) {
    if (d.isAgent) return "AGENT";
    final cat = (d.customerCategory ?? 'WHOLESALE').toUpperCase();
    return cat;
  }

  bool _matchesFilter(DebtorModel d, DebtorCategoryFilter filter) {
    switch (filter) {
      case DebtorCategoryFilter.all:
        return true;
      case DebtorCategoryFilter.agent:
        return d.isAgent;
      case DebtorCategoryFilter.wholesale:
        return d.isRegularCustomer &&
            (d.customerCategory ?? '').toUpperCase() == 'WHOLESALE';
      case DebtorCategoryFilter.vip:
        return d.isRegularCustomer &&
            (d.customerCategory ?? '').toUpperCase() == 'VIP';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDashboardSection(isMobile),
            Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 12 : 20,
                0,
                isMobile ? 12 : 20,
                20,
              ),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMobile) _buildTableHeader(),
                  if (!isMobile)
                    const Divider(height: 1, color: borderCol, thickness: 1),
                  _buildDataLayout(isMobile),
                  const Divider(height: 1, color: borderCol, thickness: 1),
                  _buildPaginationFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PermissionVisibility(
        moduleKey: 'debtor',
        action: 'create',
        child: FloatingActionButton.extended(
          onPressed: () => adddebatorDialog(controller),
          backgroundColor: primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "New Debtor",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
    );
  }

  Widget _buildDashboardSection(bool isMobile) {
    return Container(
      color: surfaceWhite,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            const Text(
              "Debtor Ledger",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Agent debtors & wholesale/VIP customer dues, in one place",
              style: TextStyle(fontSize: 12, color: textLight),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildReportButtons()),
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Debtor Ledger",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Agent debtors & wholesale/VIP customer dues, in one place",
                      style: TextStyle(fontSize: 13, color: textLight),
                    ),
                  ],
                ),
                Row(children: _buildReportButtons()),
              ],
            ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Obx(
                  () => _buildKPICard(
                    title: "Total Receivables (Due)",
                    value: controller.totalMarketOutstanding.value,
                    icon: FontAwesomeIcons.handHoldingDollar,
                    color: dangerRed,
                    isMobile: isMobile,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => _buildKPICard(
                    title: "Total Payables (Liabilities)",
                    value: controller.totalMarketPayable.value,
                    icon: FontAwesomeIcons.fileInvoiceDollar,
                    color: Colors.orange.shade800,
                    isMobile: isMobile,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  controller: pageCtrl.searchController,
                  onChanged: (val) => controller.searchDebtors(val),
                  decoration: InputDecoration(
                    hintText:
                        "Search agent debtors or wholesale/VIP customers...",
                    hintStyle: const TextStyle(fontSize: 12, color: textLight),
                    prefixIcon: const Icon(Icons.search, color: textLight),
                    filled: true,
                    fillColor: scaffoldBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderCol),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: primaryColor,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: textLight),
                      onPressed: () {
                        pageCtrl.searchController.clear();
                        controller.searchDebtors('');
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed:
                    () => controller.searchDebtors(
                      pageCtrl.searchController.text,
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(60, 48),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Search",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Refresh dues",
                onPressed: () async {
                  await controller.refreshRegularCustomerDues();
                  await controller.loadPage(controller.currentPage.value);
                },
                icon: const Icon(Icons.refresh, color: textLight),
                style: IconButton.styleFrom(
                  backgroundColor: scaffoldBg,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: borderCol),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // --- CATEGORY FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(
              () => Row(
                children: [
                  _filterChip("All", DebtorCategoryFilter.all, textDark),
                  const SizedBox(width: 8),
                  _filterChip(
                    "Agent Debtors",
                    DebtorCategoryFilter.agent,
                    primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    "Wholesale",
                    DebtorCategoryFilter.wholesale,
                    wholesaleColor,
                  ),
                  const SizedBox(width: 8),
                  _filterChip("VIP", DebtorCategoryFilter.vip, vipColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, DebtorCategoryFilter value, Color color) {
    final bool selected = pageCtrl.categoryFilter.value == value;
    return InkWell(
      onTap: () => pageCtrl.categoryFilter.value = value,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  void _showDueReportOptions() {
    Get.dialog(
      AlertDialog(
        title: const Text("Receivable Due Report"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Agent Due Report"),
              onTap: () {
                Get.back();
                controller.downloadAllDebtorsReport(reportType: 'agent');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text("Wholesale / VIP Due Report"),
              onTap: () {
                Get.back();
                controller.downloadAllDebtorsReport(reportType: 'regular');
              },
            ),
            ListTile(
              leading: const Icon(Icons.all_inbox),
              title: const Text("Both Together"),
              onTap: () {
                Get.back();
                controller.downloadAllDebtorsReport(reportType: 'both');
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReportButtons() {
    return [
      PermissionVisibility(
        moduleKey: 'debtor',
        action: 'sync',
        child: _buildReportButton(
          icon: Icons.sync,
          label: "Sync Balances",
          onTap: _confirmSyncDialog,
          color: Colors.purple,
        ),
      ),
      const SizedBox(width: 8),
      PermissionVisibility(
        moduleKey: 'debtor',
        action: 'report',
        child: _buildReportButton(
          icon: Icons.auto_fix_high,
          label: "Fix Search",
          onTap: _confirmRepairDialog,
          color: Colors.blueAccent,
        ),
      ),
      const SizedBox(width: 8),
      PermissionVisibility(
        moduleKey: 'debtor',
        action: 'report',
        child: _buildReportButton(
          icon: Icons.upload_file,
          label: "Payables Rpt",
          onTap: controller.downloadAllPayablesReport,
          color: Colors.orange.shade700,
        ),
      ),
      const SizedBox(width: 8),
      PermissionVisibility(
        moduleKey: 'debtor',
        action: 'report',
        child: _buildReportButton(
          icon: Icons.download_for_offline,
          label: "Due Report",
          onTap: _showDueReportOptions,
          color: primaryColor,
        ),
      ),
      const SizedBox(width: 8),
      PermissionVisibility(
        moduleKey: 'debtor',
        action: 'report',
        child: _buildReportButton(
          icon: FontAwesomeIcons.gift,
          label: "Eid Bonus Rpt",
          onTap: controller.downloadYearlyEidBonusReport,
          color: Colors.teal,
        ),
      ),
    ];
  }

  Widget _buildKPICard({
    required String title,
    required double value,
    final dynamic icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                icon is IconData
                    ? Icon(icon, color: color, size: isMobile ? 18 : 20)
                    : FaIcon(icon, color: color, size: isMobile ? 18 : 20),
          ),
          SizedBox(width: isMobile ? 10 : 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 8 : 11,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bdCurrency.format(value),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton({
    final dynamic icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            icon is IconData
                ? Icon(icon, size: 16, color: color)
                : FaIcon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataLayout(bool isMobile) {
    return Obx(() {
      if (controller.isBodiesLoading.value) {
        return const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator(color: primaryColor)),
        );
      }

      final visible =
          controller.filteredBodies
              .where((d) => _matchesFilter(d, pageCtrl.categoryFilter.value))
              .toList();

      if (visible.isEmpty) {
        return SizedBox(height: 300, child: _buildEmptyState());
      }

      if (isMobile) {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildMobileCard(visible[index]),
        );
      } else {
        return _buildDesktopTable(visible);
      }
    });
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          _colHeader("CLIENT DETAILS", flex: 3),
          _colHeader("CONTACT INFO", flex: 2),
          _colHeader("BALANCE STATUS", flex: 2, align: TextAlign.right),
          _colHeader("LOCATION", flex: 2),
          const SizedBox(
            width: 70,
            child: Text(
              "ACTION",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colHeader(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<DebtorModel> visible) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                itemBuilder:
                    (context, index) => _buildDesktopRow(visible[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  // Small pill next to the name showing AGENT / WHOLESALE / VIP.
  Widget _sourceBadge(DebtorModel d) {
    final Color c = _categoryColor(d);
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _categoryLabel(d),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _openDebtor(dynamic debtor) {
    if (debtor.isAgent) {
      Get.to(() => Debatordetails(id: debtor.id, name: debtor.name));
    } else {
      Get.to(
        () => _RegularCustomerDetailsPage(
          debtor: debtor,
          categoryColor: _categoryColor(debtor),
        ),
      );
    }
  }

  Widget _buildDesktopRow(dynamic debtor) {
    double bal = debtor.balance;
    bool isDue = bal > 0;
    bool isAgent = debtor.isAgent;
    Color catColor = _categoryColor(debtor);

    return InkWell(
      onTap: () => _openDebtor(debtor),
      hoverColor: Colors.grey.shade50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: borderCol)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: catColor.withValues(alpha: 0.1),
                    child: Text(
                      debtor.name.isNotEmpty
                          ? debtor.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: catColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textDark,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (debtor.des.isNotEmpty)
                          Text(
                            debtor.des,
                            style: const TextStyle(
                              color: textLight,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        _sourceBadge(debtor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: textLight),
                      const SizedBox(width: 6),
                      Text(
                        debtor.phone,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (debtor.nid.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "NID: ${debtor.nid}",
                        style: const TextStyle(color: textLight, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDue
                              ? dangerRed.withValues(alpha: 0.1)
                              : successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bdCurrency.format(bal),
                      style: TextStyle(
                        color: isDue ? dangerRed : successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  debtor.address.isNotEmpty ? debtor.address : "N/A",
                  style: const TextStyle(color: textLight, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Builder(
                builder: (context) {
                  final roleCtrl = Get.find<RoleController>();
                  final permCtrl = Get.find<PermissionController>();

                  final canView =
                      roleCtrl.isSuperAdmin || permCtrl.can('debtor', 'view');
                  // Delete only ever operates on the `debatorbody`
                  // collection — never allow it for merged-in customer dues.
                  final canDelete =
                      isAgent &&
                      (roleCtrl.isSuperAdmin ||
                          permCtrl.can('debtor', 'delete'));

                  if (!canView && !canDelete) return const SizedBox.shrink();

                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: textLight),
                    tooltip: "Options",
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (value) {
                      if (value == 'view') {
                        _openDebtor(debtor);
                      } else if (value == 'delete') {
                        _confirmDeleteDebtor(debtor);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          if (canView)
                            PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(
                                    isAgent
                                        ? Icons.visibility
                                        : Icons.receipt_long,
                                    color: catColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isAgent
                                        ? "View Account"
                                        : "Collect Due / Invoices",
                                  ),
                                ],
                              ),
                            ),
                          if (canDelete)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: dangerRed,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Delete Debtor",
                                    style: TextStyle(color: dangerRed),
                                  ),
                                ],
                              ),
                            ),
                        ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCard(dynamic debtor) {
    double bal = debtor.balance;
    bool isDue = bal > 0;
    bool isAgent = debtor.isAgent;
    Color catColor = _categoryColor(debtor);

    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      child: InkWell(
        onTap: () => _openDebtor(debtor),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: catColor.withValues(alpha: 0.1),
                    child: Text(
                      debtor.name.isNotEmpty
                          ? debtor.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: catColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textDark,
                          ),
                        ),
                        if (debtor.des.isNotEmpty)
                          Text(
                            debtor.des,
                            style: const TextStyle(
                              fontSize: 12,
                              color: textLight,
                            ),
                          ),
                        _sourceBadge(debtor),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final roleCtrl = Get.find<RoleController>();
                      final permCtrl = Get.find<PermissionController>();

                      final canView =
                          roleCtrl.isSuperAdmin ||
                          permCtrl.can('debtor', 'view');
                      final canDelete =
                          isAgent &&
                          (roleCtrl.isSuperAdmin ||
                              permCtrl.can('debtor', 'delete'));

                      if (!canView && !canDelete) {
                        return const SizedBox.shrink();
                      }

                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: textLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (value) {
                          if (value == 'view') {
                            _openDebtor(debtor);
                          } else if (value == 'delete') {
                            _confirmDeleteDebtor(debtor);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              if (canView)
                                PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isAgent
                                            ? Icons.visibility
                                            : Icons.receipt_long,
                                        color: catColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        isAgent
                                            ? "View Account"
                                            : "Collect Due",
                                      ),
                                    ],
                                  ),
                                ),
                              if (canDelete)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: dangerRed,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "Delete",
                                        style: TextStyle(color: dangerRed),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 12,
                                color: textLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                debtor.phone,
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (debtor.nid.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "NID: ${debtor.nid}",
                                style: const TextStyle(
                                  color: textLight,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDue
                                  ? dangerRed.withValues(alpha: 0.1)
                                  : successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bdCurrency.format(bal),
                          style: TextStyle(
                            color: isDue ? dangerRed : successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (debtor.address.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: borderCol),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: textLight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            debtor.address,
                            style: const TextStyle(
                              color: textLight,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 40,
              color: textLight.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No matching debtors found.",
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Try checking for spelling, a different keyword, or clearing the category filter.",
            style: TextStyle(color: textLight, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Obx(() {
      if (controller.isSearching.value) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          color: surfaceWhite,
          border: Border(top: BorderSide(color: borderCol)),
        ),
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed:
                  controller.currentPage.value > 1 ? controller.prevPage : null,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: const Text("Previous"),
              style: ElevatedButton.styleFrom(
                backgroundColor: scaffoldBg,
                foregroundColor: textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                disabledBackgroundColor: Colors.grey.shade100,
                disabledForegroundColor: Colors.grey.shade400,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Page ${controller.currentPage.value}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: controller.hasMore.value ? controller.nextPage : null,
              icon: const Icon(Icons.arrow_forward_ios, size: 14),
              label: const Text("Next"),
              style: ElevatedButton.styleFrom(
                backgroundColor: scaffoldBg,
                foregroundColor: textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                disabledBackgroundColor: Colors.grey.shade100,
                disabledForegroundColor: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    });
  }

  void _confirmSyncDialog() {
    Get.defaultDialog(
      title: "Synchronize Balances",
      middleText:
          "This will recalculate all agent-debtor balances perfectly from their transaction history to fix any mismatches in your PDFs or Dashboard. Wholesale/VIP customer dues are updated live as you collect payments.",
      textConfirm: "Sync Now",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: primaryColor,
      onConfirm: () {
        Get.back();
        controller.syncAllBalances();
      },
    );
  }

  void _confirmRepairDialog() {
    Get.defaultDialog(
      title: "Upgrade Search Data",
      middleText:
          "This will update all existing debtors in the database to support the new multi-word description search.",
      textConfirm: "Upgrade Now",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: primaryColor,
      onConfirm: () {
        Get.back();
        controller.repairSearchKeywords();
      },
    );
  }

  void _confirmDeleteDebtor(dynamic debtor) {
    if (!debtor.isAgent) {
      Get.snackbar(
        "Not Allowed",
        "Wholesale/VIP customer records are managed from the Customers module.",
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: dangerRed, size: 28),
            SizedBox(width: 10),
            Text(
              "Delete Debtor",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete '${debtor.name}'?\n\nThis will also delete ALL associated transactions for this debtor. This action cannot be undone.",
          style: const TextStyle(color: textDark, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Get.back();
              controller.deleteDebtor(debtor.id);
            },
            child: const Text(
              "Delete Forever",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}

// ============================================================================
// WHOLESALE / VIP CUSTOMER LEDGER DIALOG
// (Collect Due + Invoice list + Reprint — the customer-side equivalent of
// the agent debtor's Debatordetails page, but scoped to what's actually
// possible against the `customers` + `daily_sales` data model.)
// ============================================================================

class _CustomerLedgerController extends GetxController {
  final DebtorModel debtor;
  final DebatorController mainCtrl;
  _CustomerLedgerController(this.debtor, this.mainCtrl);

  final RxBool isLoadingInvoices = true.obs;
  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxInt selectedTab = 0.obs;

  // Collect-due form state
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final bankNameC = TextEditingController();
  final accountNoC = TextEditingController();
  final mobileNoC = TextEditingController();
  final RxString payMethodType = 'cash'.obs;
  final RxBool showCollectForm = false.obs;
  final RxBool isSubmitting = false.obs;

  // Discount form state
  final discountC = TextEditingController();
  final discountNoteC = TextEditingController();
  final RxBool showDiscountForm = false.obs;
  final RxBool isDiscountSubmitting = false.obs;

  List<Map<String, dynamic>> get activityEntries {
    final entries = <Map<String, dynamic>>[];
    for (final inv in invoices) {
      final List<dynamic> paymentHistory =
          (inv['paymentHistory'] as List<dynamic>? ?? []);

      if (paymentHistory.isNotEmpty) {
        for (final item in paymentHistory) {
          if (item is! Map) continue;
          final data = Map<String, dynamic>.from(item);
          final timestamp = data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now();
          entries.add({
            'title': (data['note'] ?? 'Payment').toString(),
            'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
            'type': (data['type'] ?? 'payment').toString(),
            'date': timestamp,
          });
        }
      } else {
        final timestamp = inv['timestamp'] is Timestamp
            ? (inv['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        entries.add({
          'title': 'Invoice ${inv['invoiceId'] ?? inv['transactionId'] ?? 'created'}',
          'amount': (inv['pending'] as num?)?.toDouble() ?? 0.0,
          'type': 'invoice',
          'date': timestamp,
        });
      }
    }

    entries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return entries;
  }

  @override
  void onInit() {
    super.onInit();
    _loadInvoices();
  }

  @override
  void onClose() {
    amountC.dispose();
    noteC.dispose();
    bankNameC.dispose();
    accountNoC.dispose();
    mobileNoC.dispose();
    discountC.dispose();
    discountNoteC.dispose();
    super.onClose();
  }

  Future<void> _loadInvoices() async {
    isLoadingInvoices.value = true;
    final list = await mainCtrl.getRegularCustomerInvoices(
      customerName: debtor.name,
      customerCategory: debtor.customerCategory,
      customerPhone: debtor.phone,
    );
    invoices.value = list;
    isLoadingInvoices.value = false;
  }

  @override
  Future<void> refresh() async {
    await _loadInvoices();
  }

  Future<void> submitDiscount() async {
    double amount = double.tryParse(discountC.text.trim()) ?? 0;
    if (amount <= 0) {
      Get.snackbar("Error", "Enter a valid discount amount.");
      return;
    }

    isDiscountSubmitting.value = true;
    try {
      await mainCtrl.applyRegularCustomerDiscount(
        customerId: debtor.id,
        customerName: debtor.name,
        customerCategory: debtor.customerCategory,
        amount: amount,
        note: discountNoteC.text.trim(),
        date: DateTime.now(),
      );

      discountC.clear();
      discountNoteC.clear();
      showDiscountForm.value = false;
      await _loadInvoices();
    } finally {
      isDiscountSubmitting.value = false;
    }
  }

  Future<void> submitCollection() async {
    double amount = double.tryParse(amountC.text.trim()) ?? 0;
    if (amount <= 0) {
      Get.snackbar("Error", "Enter a valid amount to collect.");
      return;
    }

    isSubmitting.value = true;
    try {
      Map<String, dynamic> pm = {'type': 'cash'};
      if (payMethodType.value == 'bank') {
        pm = {
          'type': 'bank',
          'bankName': bankNameC.text.trim(),
          'accountNo': accountNoC.text.trim(),
        };
      } else if (['bkash', 'nagad', 'rocket'].contains(payMethodType.value)) {
        pm = {'type': payMethodType.value, 'number': mobileNoC.text.trim()};
      }

      await mainCtrl.collectRegularCustomerDue(
        customerId: debtor.id,
        customerName: debtor.name,
        customerCategory: debtor.customerCategory,
        amount: amount,
        note: noteC.text.trim(),
        date: DateTime.now(),
        paymentMethodData: pm,
      );

      amountC.clear();
      noteC.clear();
      bankNameC.clear();
      accountNoC.clear();
      mobileNoC.clear();
      showCollectForm.value = false;
      await _loadInvoices();
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> reprintInvoice(String invoiceId) async {
    try {
      if (!Get.isRegistered<DailySalesController>()) {
        Get.put(DailySalesController());
      }
      await Get.find<DailySalesController>().reprintInvoice(invoiceId);
    } catch (e) {
      Get.snackbar("Error", "Could not load invoice: $e");
    }
  }
}

class _RegularCustomerDetailsController extends GetxController {
  final DebtorModel debtor;
  final DebatorController mainCtrl;

  _RegularCustomerDetailsController(this.debtor, this.mainCtrl);

  final RxBool isLoading = true.obs;
  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxString searchText = ''.obs;
  final Rx<String> filter = 'All'.obs;

  List<Map<String, dynamic>> get transactionRows {
    final rows = <Map<String, dynamic>>[];

    for (final inv in invoices) {
      final String invoiceId =
          (inv['invoiceId'] ?? inv['transactionId'] ?? '').toString();
      final String invoiceLabel = invoiceId.isEmpty ? 'Invoice' : invoiceId;
      final DateTime date = inv['timestamp'] is Timestamp
          ? (inv['timestamp'] as Timestamp).toDate()
          : DateTime.now();
      final double amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;

      final List<dynamic> paymentHistory =
          (inv['paymentHistory'] as List<dynamic>? ?? []);
      final sameDayPayments = <Map<String, dynamic>>[];
      final laterPayments = <Map<String, dynamic>>[];
      for (final item in paymentHistory) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final paymentDate = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : date;
        // Initial payment entries created with the invoice do not have a
        // collectionMode. Every later collection must remain its own row,
        // including collections made on the invoice date.
        final isInitialPayment = !data.containsKey('collectionMode');
        final target = isInitialPayment ? sameDayPayments : laterPayments;
        target.add({
          ...data,
          '_date': paymentDate,
          '_amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
        });
      }

      final sameDayCredit = sameDayPayments.fold<double>(
        0.0,
        (total, payment) => total + (payment['_amount'] as double),
      );
      rows.add({
        'id':
            'invoice-${invoiceId.isEmpty ? date.millisecondsSinceEpoch : invoiceId}',
        'date': date,
        'label': 'INVOICE / DUE',
        'note': invoiceLabel,
        'debit': amount,
        'credit': sameDayCredit.clamp(0.0, amount),
        'due': (amount - sameDayCredit).clamp(0.0, amount),
        'paymentMethod': <String, dynamic>{
          'type': sameDayPayments.isEmpty
              ? 'invoice'
              : sameDayPayments
                  .map((payment) => (payment['type'] ?? 'cash').toString())
                  .toSet()
                  .join(', '),
        },
      });

      laterPayments.sort(
        (a, b) => (a['_date'] as DateTime).compareTo(b['_date'] as DateTime),
      );
      var runningDue = (amount - sameDayCredit).clamp(0.0, amount);
      for (int index = 0; index < laterPayments.length; index++) {
        final payment = laterPayments[index];
        final paymentAmount = payment['_amount'] as double;
        runningDue = (runningDue - paymentAmount).clamp(0.0, amount);
        rows.add({
          'id':
              'payment-${invoiceId.isEmpty ? date.millisecondsSinceEpoch : invoiceId}-$index',
          'date': payment['_date'],
          'label': 'PAYMENT',
          'note': (payment['note'] ?? 'Due Collection').toString(),
          'debit': 0.0,
          'credit': paymentAmount,
          'due': runningDue,
          'paymentMethod': <String, dynamic>{
            'type': (payment['type'] ?? 'cash').toString(),
            if ((payment['bankName'] ?? '').toString().isNotEmpty)
              'bankName': payment['bankName'],
          },
        });
      }
    }

    rows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    final q = searchText.value.trim().toLowerCase();
    return rows.where((row) {
      final note = (row['note'] ?? '').toString().toLowerCase();
      final paymentMethod = (row['paymentMethod'] ?? {}).toString().toLowerCase();
      final due = (row['due'] as num).toDouble();
      final bool matchFilter =
          filter.value == 'All' ||
          (filter.value == 'Due' && due > 0.5) ||
          (filter.value == 'Paid' && due <= 0.5);
      final bool matchText =
          q.isEmpty || note.contains(q) || paymentMethod.contains(q);
      return matchFilter && matchText;
    }).toList();
  }

  Future<void> loadInvoices() async {
    isLoading.value = true;
    try {
      final list = await mainCtrl.getRegularCustomerInvoices(
        customerName: debtor.name,
        customerCategory: debtor.customerCategory,
        customerPhone: debtor.phone,
      );
      invoices.assignAll(list);
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredInvoices {
    final q = searchText.value.trim().toLowerCase();
    final rows = <Map<String, dynamic>>[];
    for (final inv in invoices) {
      final String invoiceId =
          (inv['invoiceId'] ?? inv['transactionId'] ?? '').toString();
      final double pending = (inv['pending'] as num?)?.toDouble() ?? 0.0;
      final String status = pending > 0.5 ? 'Due' : 'Paid';
      final bool matchFilter =
          filter.value == 'All' || status == filter.value;
      final bool matchText =
          q.isEmpty ||
          invoiceId.toLowerCase().contains(q) ||
          (inv['name'] ?? '').toString().toLowerCase().contains(q);
      if (matchFilter && matchText) rows.add(inv);
    }
    rows.sort((a, b) {
      final t1 = a['timestamp'] is Timestamp ? (a['timestamp'] as Timestamp).toDate() : DateTime.now();
      final t2 = b['timestamp'] is Timestamp ? (b['timestamp'] as Timestamp).toDate() : DateTime.now();
      return t2.compareTo(t1);
    });
    return rows;
  }

  String paymentLabel(Map<String, dynamic>? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) return 'Invoice';
    final type = (paymentMethod['type'] ?? 'cash').toString();
    if (type == 'bank') {
      final bankName = (paymentMethod['bankName'] ?? '').toString();
      return bankName.isNotEmpty ? '$bankName Bank' : 'Bank';
    }
    if (type == 'cash') return 'Cash';
    if (type == 'bkash') return 'Bkash';
    if (type == 'nagad') return 'Nagad';
    if (type == 'rocket') return 'Rocket';
    if (type.contains(',')) {
      return type
          .split(',')
          .map((value) => paymentLabel({'type': value.trim()}))
          .join(' + ');
    }
    return type.toUpperCase();
  }

  Future<void> printInvoice(String invoiceId) async {
    try {
      if (!Get.isRegistered<DailySalesController>()) {
        Get.put(DailySalesController());
      }
      await Get.find<DailySalesController>().reprintInvoice(invoiceId);
    } catch (e) {
      Get.snackbar('Error', 'Could not load invoice: $e');
    }
  }

  Future<void> collectDue({
    required double amount,
    required String note,
    required Map<String, dynamic> paymentMethod,
  }) async {
    await mainCtrl.collectRegularCustomerDue(
      customerId: debtor.id,
      customerName: debtor.name,
      customerCategory: debtor.customerCategory,
      amount: amount,
      note: note,
      date: DateTime.now(),
      paymentMethodData: paymentMethod,
    );
    await loadInvoices();
  }

  Future<void> applyDiscount({
    required double amount,
    required String note,
  }) async {
    await mainCtrl.applyRegularCustomerDiscount(
      customerId: debtor.id,
      customerName: debtor.name,
      customerCategory: debtor.customerCategory,
      amount: amount,
      note: note,
      date: DateTime.now(),
    );
    await loadInvoices();
  }

  Future<void> exportStatement() async {
    await mainCtrl.downloadRegularCustomerStatement(
      debtor.id,
      debtor.name,
      customerCategory: debtor.customerCategory,
    );
  }
}

class _RegularCustomerDetailsPage extends StatelessWidget {
  final DebtorModel debtor;
  final Color categoryColor;

  const _RegularCustomerDetailsPage({
    required this.debtor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final pageCtrl = Get.put(
      _RegularCustomerDetailsController(debtor, Get.find<DebatorController>()),
      tag: debtor.id,
    );
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    pageCtrl.loadInvoices();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              debtor.name,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const Text(
              'Financial Ledger',
              style: TextStyle(
                color: textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: pageCtrl.exportStatement,
            icon: const FaIcon(FontAwesomeIcons.filePdf, size: 14, color: dangerRed),
            label: const Text('Statement', style: TextStyle(color: dangerRed, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: categoryColor,
        onPressed: () => _showRegularCustomerActionSheet(context, pageCtrl),
        icon: const Icon(Icons.add_card, color: Colors.white),
        label: const Text('New Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        final balance = pageCtrl.mainCtrl.regularCustomerDues
            .firstWhereOrNull((d) => d.id == debtor.id)
            ?.balance ?? debtor.balance;
        final lastUpdate = pageCtrl.invoices.isNotEmpty
            ? pageCtrl.invoices
                .map((inv) => inv['timestamp'])
                .whereType<Timestamp>()
                .map((ts) => ts.toDate())
                .toList()
                .fold<DateTime?>(null, (prev, date) {
                  if (prev == null || date.isAfter(prev)) return date;
                  return prev;
                })
            : null;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'TOTAL OUTSTANDING',
                      value: '৳ ${balance.toStringAsFixed(0)}',
                      accent: dangerRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'INVOICES',
                      value: pageCtrl.invoices.length.toString(),
                      accent: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'LAST UPDATE',
                      value: lastUpdate == null ? '-' : DateFormat('dd MMM').format(lastUpdate),
                      accent: successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => pageCtrl.searchText.value = v,
                        decoration: InputDecoration(
                          hintText: 'Search invoice or note',
                          prefixIcon: const Icon(Icons.search, size: 18, color: textLight),
                          filled: true,
                          fillColor: scaffoldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: pageCtrl.filter.value,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Due', child: Text('Due')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      ],
                      onChanged: (v) {
                        if (v != null) pageCtrl.filter.value = v;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (pageCtrl.isLoading.value)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                )
              else if (pageCtrl.transactionRows.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No invoice records found for this customer.', style: TextStyle(color: textLight)),
                  ),
                )
              else
                isMobile
                    ? _buildRegularMobileTransactions(pageCtrl)
                    : _buildRegularDesktopTransactions(pageCtrl),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRegularDesktopTransactions(
    _RegularCustomerDetailsController pageCtrl,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: textLight, letterSpacing: 0.5))),
                Expanded(flex: 4, child: Text('DETAILS / INVOICE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: textLight, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('DEBIT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: dangerRed, letterSpacing: 0.5)))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('CREDIT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: successGreen, letterSpacing: 0.5)))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('DUE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: textLight, letterSpacing: 0.5)))),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pageCtrl.transactionRows.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (_, index) => _buildRegularDesktopRow(
              pageCtrl.transactionRows[index],
              pageCtrl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularDesktopRow(
    Map<String, dynamic> tx,
    _RegularCustomerDetailsController pageCtrl,
  ) {
    final date = tx['date'] as DateTime;
    final note = (tx['note'] ?? '-').toString();
    final debit = (tx['debit'] as num).toDouble();
    final credit = (tx['credit'] as num).toDouble();
    final due = (tx['due'] as num).toDouble();
    final method = pageCtrl.paymentLabel(
      tx['paymentMethod'] as Map<String, dynamic>?,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM yyyy').format(date),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textLight),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVOICE / DUE',
                  style: TextStyle(color: dangerRed, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: note == '-' ? null : () => pageCtrl.printInvoice(note),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.print, size: 12, color: primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(method, style: const TextStyle(fontSize: 11, color: textLight, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('৳${debit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: dangerRed, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(credit > 0 ? '৳${credit.toStringAsFixed(0)}' : '-', style: const TextStyle(fontSize: 13, color: successGreen, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('৳${due.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: due > 0.5 ? dangerRed : successGreen, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularMobileTransactions(
    _RegularCustomerDetailsController pageCtrl,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pageCtrl.transactionRows.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (_, index) {
          final tx = pageCtrl.transactionRows[index];
          final date = tx['date'] as DateTime;
          final note = (tx['note'] ?? '-').toString();
          final debit = (tx['debit'] as num).toDouble();
          final credit = (tx['credit'] as num).toDouble();
          final due = (tx['due'] as num).toDouble();
          final method = pageCtrl.paymentLabel(tx['paymentMethod'] as Map<String, dynamic>?);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textLight)),
                    const Text('INVOICE / DUE', style: TextStyle(color: dangerRed, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: note == '-' ? null : () => pageCtrl.printInvoice(note),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.print, size: 14, color: primaryColor),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(method, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textLight)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _regularAmountBadge('DR', debit, dangerRed),
                    const SizedBox(width: 8),
                    _regularAmountBadge('CR', credit, successGreen),
                    const SizedBox(width: 8),
                    _regularAmountBadge('DUE', due, due > 0.5 ? dangerRed : successGreen),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _regularAmountBadge(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: ৳${value.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  void _showRegularCustomerActionSheet(BuildContext context, _RegularCustomerDetailsController pageCtrl) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Customer Action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.payments, color: successGreen),
                title: const Text('Collect Due'),
                onTap: () {
                  Get.back();
                  _showCollectForm(context, pageCtrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.discount_outlined, color: Colors.orange),
                title: const Text('Add Discount'),
                onTap: () {
                  Get.back();
                  _showDiscountForm(context, pageCtrl);
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCollectForm(BuildContext context, _RegularCustomerDetailsController pageCtrl) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final bankNameC = TextEditingController();
    final accountNoC = TextEditingController();
    final mobileNoC = TextEditingController();
    final payMethod = 'cash'.obs;
    final isSubmitting = false.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('Collect Due'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount Collected (Tk)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteC,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
                const SizedBox(height: 10),
                Obx(
                  () => DropdownButtonFormField<String>(
                    value: payMethod.value,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'bkash', child: Text('Bkash')),
                      DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                      DropdownMenuItem(value: 'rocket', child: Text('Rocket')),
                    ],
                    onChanged: (v) => payMethod.value = v ?? 'cash',
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                  ),
                ),
                const SizedBox(height: 10),
                Obx(() {
                  if (payMethod.value == 'bank') {
                    return Column(
                      children: [
                        TextField(controller: bankNameC, decoration: const InputDecoration(labelText: 'Bank Name')),
                        TextField(controller: accountNoC, decoration: const InputDecoration(labelText: 'Account Number')),
                      ],
                    );
                  }
                  if (['bkash', 'nagad', 'rocket'].contains(payMethod.value)) {
                    return TextField(
                      controller: mobileNoC,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: '${payMethod.value.capitalizeFirst} Number'),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
        actions: [
          Obx(
            () => TextButton(
              onPressed: isSubmitting.value ? null : () => Get.back(),
              child: const Text('Cancel'),
            ),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: isSubmitting.value
                  ? null
                  : () async {
                      final amount =
                          double.tryParse(amountC.text.trim()) ?? 0.0;
                      if (amount <= 0) {
                        Get.snackbar('Error', 'Enter a valid amount to collect.');
                        return;
                      }
                      final pm = {
                        'type': payMethod.value,
                        if (payMethod.value == 'bank') ...{
                          'bankName': bankNameC.text.trim(),
                          'accountNo': accountNoC.text.trim(),
                        },
                        if (['bkash', 'nagad', 'rocket']
                            .contains(payMethod.value))
                          'number': mobileNoC.text.trim(),
                      };

                      isSubmitting.value = true;
                      try {
                        await pageCtrl.collectDue(
                          amount: amount,
                          note: noteC.text.trim(),
                          paymentMethod: pm,
                        );
                        if (Get.isDialogOpen ?? false) Get.back();
                      } finally {
                        isSubmitting.value = false;
                      }
                    },
              child: isSubmitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscountForm(BuildContext context, _RegularCustomerDetailsController pageCtrl) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Discount'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Discount Amount (Tk)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountC.text.trim()) ?? 0.0;
              Get.back();
              if (amount > 0) {
                await pageCtrl.applyDiscount(amount: amount, note: noteC.text.trim());
              }
            },
            child: const Text('Apply Discount'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textLight, letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CustomerLedgerDialog extends StatelessWidget {
  final DebtorModel debtor;
  final Color categoryColor;
  final _CustomerLedgerController ledgerCtrl;

  const _CustomerLedgerDialog({
    required this.debtor,
    required this.categoryColor,
    required this.ledgerCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 60,
        vertical: 24,
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.crown,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtor.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${(debtor.customerCategory ?? 'WHOLESALE').toUpperCase()} CUSTOMER  •  ${debtor.phone}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Obx(() {
                final freshDebtor = ledgerCtrl.mainCtrl.regularCustomerDues
                    .firstWhereOrNull((d) => d.id == debtor.id);
                final double liveBalance = freshDebtor?.balance ?? debtor.balance;
                final lastTx = ledgerCtrl.activityEntries.isNotEmpty
                    ? ledgerCtrl.activityEntries.first['date'] as DateTime?
                    : null;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ledgerStatCard(
                            title: 'OUTSTANDING DUE',
                            value: '৳ ${liveBalance.toStringAsFixed(0)}',
                            color: dangerRed,
                            bgColor: dangerRed.withValues(alpha: 0.06),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ledgerStatCard(
                            title: 'INVOICES',
                            value: ledgerCtrl.invoices.length.toString(),
                            color: primaryColor,
                            bgColor: primaryColor.withValues(alpha: 0.06),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ledgerStatCard(
                            title: 'LAST UPDATE',
                            value: lastTx == null ? '-' : DateFormat('dd MMM').format(lastTx),
                            color: successGreen,
                            bgColor: successGreen.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                liveBalance <= 0
                                    ? null
                                    : () => ledgerCtrl.showCollectForm.toggle(),
                            icon: const Icon(Icons.payments, size: 18),
                            label: const Text('Collect Due'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                liveBalance <= 0
                                    ? null
                                    : () => ledgerCtrl.showDiscountForm.toggle(),
                            icon: const Icon(Icons.discount_outlined, size: 18),
                            label: const Text('Discount'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              side: BorderSide(color: Colors.orange.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),

            Obx(
              () => ledgerCtrl.showCollectForm.value
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _CollectDueForm(ledgerCtrl: ledgerCtrl),
                    )
                  : const SizedBox.shrink(),
            ),

            Obx(
              () => ledgerCtrl.showDiscountForm.value
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _DiscountForm(ledgerCtrl: ledgerCtrl),
                    )
                  : const SizedBox.shrink(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _tabButton('Invoices', 0),
                  const SizedBox(width: 8),
                  _tabButton('Activity', 1),
                  const Spacer(),
                  Obx(
                    () => IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: textLight),
                      onPressed: ledgerCtrl.isLoadingInvoices.value
                          ? null
                          : () async => ledgerCtrl.refresh(),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 24, color: borderCol),
            ),
            Expanded(
              child: Obx(() {
                if (ledgerCtrl.isLoadingInvoices.value) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  );
                }
                if (ledgerCtrl.selectedTab.value == 1) {
                  final history = ledgerCtrl.activityEntries;
                  if (history.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'No transaction activity for this customer yet.',
                          style: TextStyle(color: textLight),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: borderCol),
                    itemBuilder: (context, index) => _historyRow(history[index]),
                  );
                }
                if (ledgerCtrl.invoices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: Text(
                        'No invoices found for this customer.',
                        style: TextStyle(color: textLight),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                  itemCount: ledgerCtrl.invoices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: borderCol),
                  itemBuilder: (context, index) {
                    final inv = ledgerCtrl.invoices[index];
                    return _invoiceRow(inv);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    return Obx(
      () => InkWell(
        onTap: () => ledgerCtrl.selectedTab.value = index,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: ledgerCtrl.selectedTab.value == index
                ? primaryColor.withValues(alpha: 0.08)
                : scaffoldBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ledgerCtrl.selectedTab.value == index
                  ? primaryColor.withValues(alpha: 0.3)
                  : borderCol,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: ledgerCtrl.selectedTab.value == index ? primaryColor : textLight,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ledgerStatCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: textLight,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> entry) {
    final double amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
    final DateTime date = entry['date'] as DateTime? ?? DateTime.now();
    final String type = (entry['type'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: type.toLowerCase() == 'discount'
                  ? Colors.orange.withValues(alpha: 0.1)
                  : successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              type.toLowerCase() == 'discount' ? Icons.discount_outlined : Icons.receipt_long,
              color: type.toLowerCase() == 'discount' ? Colors.orange.shade800 : successGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (entry['title'] ?? 'Transaction').toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd MMM yyyy • hh:mm a').format(date),
                  style: const TextStyle(fontSize: 11, color: textLight),
                ),
              ],
            ),
          ),
          Text(
            '৳ ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: type.toLowerCase() == 'discount' ? Colors.orange.shade800 : primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(Map<String, dynamic> inv) {
    double amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;
    double pending = (inv['pending'] as num?)?.toDouble() ?? 0.0;
    String status = (inv['status'] ?? '').toString();
    String invoiceId =
        (inv['invoiceId'] ?? inv['transactionId'] ?? '').toString();
    DateTime? date =
        inv['timestamp'] is Timestamp
            ? (inv['timestamp'] as Timestamp).toDate()
            : null;

    bool isPaid = status.toLowerCase() == 'paid' || pending <= 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap:
                      invoiceId.isEmpty
                          ? null
                          : () => ledgerCtrl.reprintInvoice(invoiceId),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          invoiceId.isEmpty ? "Invoice" : invoiceId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.print, size: 14, color: primaryColor),
                    ],
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(fontSize: 11, color: textLight),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "৳ ${amount.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: textLight),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "৳ ${pending.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: pending > 0.5 ? dangerRed : successGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  isPaid
                      ? successGreen.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPaid ? "PAID" : "DUE",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPaid ? successGreen : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountForm extends StatelessWidget {
  final _CustomerLedgerController ledgerCtrl;
  const _DiscountForm({required this.ledgerCtrl});

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool isNum = false,
  }) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 16, color: textLight),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: scaffoldBg,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            ledgerCtrl.discountC,
            'Discount Amount (Tk)',
            Icons.discount_outlined,
            isNum: true,
          ),
          const SizedBox(height: 10),
          _field(ledgerCtrl.discountNoteC, 'Discount Note (optional)', Icons.note),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => ledgerCtrl.showDiscountForm.value = false,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Obx(
                () => ElevatedButton(
                  onPressed: ledgerCtrl.isDiscountSubmitting.value
                      ? null
                      : ledgerCtrl.submitDiscount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: ledgerCtrl.isDiscountSubmitting.value
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Apply Discount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectDueForm extends StatelessWidget {
  final _CustomerLedgerController ledgerCtrl;
  const _CollectDueForm({required this.ledgerCtrl});

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool isNum = false,
  }) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 16, color: textLight),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: scaffoldBg,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: successGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: successGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            ledgerCtrl.amountC,
            "Amount Collected (Tk)",
            Icons.attach_money,
            isNum: true,
          ),
          const SizedBox(height: 10),
          _field(ledgerCtrl.noteC, "Note (optional)", Icons.note),
          const SizedBox(height: 10),
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: ledgerCtrl.payMethodType.value,
                  isExpanded: true,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text("Cash")),
                    DropdownMenuItem(
                      value: 'bank',
                      child: Text("Bank Transfer"),
                    ),
                    DropdownMenuItem(value: 'bkash', child: Text("Bkash")),
                    DropdownMenuItem(value: 'nagad', child: Text("Nagad")),
                    DropdownMenuItem(value: 'rocket', child: Text("Rocket")),
                  ],
                  onChanged: (v) {
                    if (v != null) ledgerCtrl.payMethodType.value = v;
                  },
                ),
              ),
            ),
          ),
          Obx(() {
            if (ledgerCtrl.payMethodType.value == 'bank') {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    _field(ledgerCtrl.bankNameC, "Bank Name", Icons.business),
                    const SizedBox(height: 8),
                    _field(
                      ledgerCtrl.accountNoC,
                      "Account Number",
                      Icons.numbers,
                    ),
                  ],
                ),
              );
            } else if ([
              'bkash',
              'nagad',
              'rocket',
            ].contains(ledgerCtrl.payMethodType.value)) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _field(
                  ledgerCtrl.mobileNoC,
                  "${ledgerCtrl.payMethodType.value.capitalizeFirst} Number",
                  Icons.phone_android,
                  isNum: true,
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => ledgerCtrl.showCollectForm.value = false,
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 8),
              Obx(
                () => ElevatedButton(
                  onPressed:
                      ledgerCtrl.isSubmitting.value
                          ? null
                          : ledgerCtrl.submitCollection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      ledgerCtrl.isSubmitting.value
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Confirm Collection",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
