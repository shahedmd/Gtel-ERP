// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/createdebtordialog.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordetails_transactionlist.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:intl/intl.dart';

import '../../Permission/permission_button.dart';
import '../../Permission/permission_controller.dart';
import '../../controller.dart';

// --- ERP COLOR PALETTE ---
const Color primaryColor = Color(0xFF2563EB);
const Color scaffoldBg = Color(0xFFF8FAFC);
const Color surfaceWhite = Colors.white;
const Color textDark = Color(0xFF0F172A);
const Color textLight = Color(0xFF64748B);
const Color borderCol = Color(0xFFE2E8F0);
const Color successGreen = Color(0xFF16A34A);
const Color dangerRed = Color(0xFFDC2626);

class DebtorPageController extends GetxController {
  final TextEditingController searchController = TextEditingController();

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
  final ScrollController _vScroll = ScrollController();

  final NumberFormat bdCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '৳',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          _buildDashboardSection(isMobile),
          Expanded(
            child: Container(
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
                  Expanded(child: _buildDataLayout(isMobile)),
                  const Divider(height: 1, color: borderCol, thickness: 1),
                  _buildPaginationFooter(),
                ],
              ),
            ),
          ),
        ],
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
              "Manage receivables and customer accounts",
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
                      "Manage receivables and customer accounts",
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
                    hintText: "Search name, description, or phone...",
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
            ],
          ),
        ],
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
          onTap: controller.downloadAllDebtorsReport,
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
    required IconData icon,
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
            child: FaIcon(icon, color: color, size: isMobile ? 18 : 20),
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
    required IconData icon,
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
            Icon(icon, size: 16, color: color),
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
        return const Center(
          child: CircularProgressIndicator(color: primaryColor),
        );
      }
      if (controller.filteredBodies.isEmpty) return _buildEmptyState();

      if (isMobile) {
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.filteredBodies.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder:
              (context, index) =>
                  _buildMobileCard(controller.filteredBodies[index]),
        );
      } else {
        return _buildDesktopTable();
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

  Widget _buildDesktopTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
        return Scrollbar(
          controller: _vScroll,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _vScroll,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
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
                    itemCount: controller.filteredBodies.length,
                    itemBuilder:
                        (context, index) =>
                            _buildDesktopRow(controller.filteredBodies[index]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopRow(dynamic debtor) {
    // MEMORY SAFE: Read directly from static model instead of StreamBuilder!
    double bal = debtor.balance;
    bool isDue = bal > 0;

    return InkWell(
      onTap:
          () => Get.to(() => Debatordetails(id: debtor.id, name: debtor.name)),
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
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      debtor.name.isNotEmpty
                          ? debtor.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: primaryColor,
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
                  final canDelete =
                      roleCtrl.isSuperAdmin || permCtrl.can('debtor', 'delete');

                  // কোনো permission নেই তাহলে button hide করো
                  if (!canView && !canDelete) return const SizedBox.shrink();

                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: textLight),
                    tooltip: "Options",
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (value) {
                      if (value == 'view') {
                        Get.to(
                          () =>
                              Debatordetails(id: debtor.id, name: debtor.name),
                        );
                      } else if (value == 'delete') {
                        _confirmDeleteDebtor(debtor);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          if (canView)
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.visibility,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text("View Account"),
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
    // MEMORY SAFE: Read directly from static model instead of StreamBuilder!
    double bal = debtor.balance;
    bool isDue = bal > 0;

    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      child: InkWell(
        onTap:
            () =>
                Get.to(() => Debatordetails(id: debtor.id, name: debtor.name)),
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
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      debtor.name.isNotEmpty
                          ? debtor.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: primaryColor,
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
                          roleCtrl.isSuperAdmin ||
                          permCtrl.can('debtor', 'delete');

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
                            Get.to(
                              () => Debatordetails(
                                id: debtor.id,
                                name: debtor.name,
                              ),
                            );
                          } else if (value == 'delete') {
                            _confirmDeleteDebtor(debtor);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              if (canView)
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        color: primaryColor,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Text("View Account"),
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
            child: Icon(
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
            "Try checking for spelling or using a different keyword.",
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

  // ==========================================
  // DIALOGS
  // ==========================================
  void _confirmSyncDialog() {
    Get.defaultDialog(
      title: "Synchronize Balances",
      middleText:
          "This will recalculate all debtor balances perfectly from their transaction history to fix any mismatches in your PDFs or Dashboard.",
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
