// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'debatorcontroller.dart';
import 'adddebator.dart';
import 'details.dart';

class Debatorpage extends StatefulWidget {
  const Debatorpage({super.key});

  @override
  State<Debatorpage> createState() => _DebatorpageState();
}

class _DebatorpageState extends State<Debatorpage> {
  final DebatorController controller = Get.put(DebatorController());
  final TextEditingController _searchController = TextEditingController();

  // --- ERP COLOR PALETTE ---
  static const Color primaryColor = Color(0xFF4F46E5); // Indigo
  static const Color scaffoldBg = Color(0xFFF3F4F6); // Cool Grey
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);
  static const Color borderCol = Color(0xFFE5E7EB);
  static const Color successGreen = Color(0xFF059669);
  static const Color dangerRed = Color(0xFFDC2626);

  final NumberFormat bdCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '৳',
    decimalDigits: 2,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // 1. Top Dashboard & Toolbar
          _buildDashboardSection(),

          // 2. Data Table Header
          _buildTableHeader(),

          // 3. Data Table Body
          Expanded(
            child: Obx(() {
              if (controller.isBodiesLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              if (controller.filteredBodies.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: controller.filteredBodies.length,
                separatorBuilder:
                    (c, i) => const Divider(height: 1, color: borderCol),
                itemBuilder: (context, index) {
                  final debtor = controller.filteredBodies[index];
                  return _buildTableRow(debtor);
                },
              );
            }),
          ),

          // 4. Pagination Footer
          _buildPaginationFooter(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => adddebatorDialog(controller),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Debtor", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ==========================================
  // 1. DASHBOARD & TOOLBAR
  // ==========================================
  Widget _buildDashboardSection() {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Debtor Ledger",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    "Manage receivables and customer accounts",
                    style: TextStyle(fontSize: 13, color: textLight),
                  ),
                ],
              ),
              // Reports Dropdown / Buttons
              Row(
                children: [
                  _buildReportButton(
                    icon: Icons.auto_fix_high,
                    label: "Fix Search DB",
                    onTap: () => _confirmRepairDialog(),
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  _buildReportButton(
                    icon: Icons.upload_file,
                    label: "Payables Rpt",
                    onTap: controller.downloadAllPayablesReport,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  _buildReportButton(
                    icon: Icons.download_for_offline,
                    label: "Due Report",
                    onTap: controller.downloadAllDebtorsReport,
                    color: primaryColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Cards
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => _buildKPICard(
                    title: "Total Receivables (Due)",
                    value: controller.totalMarketOutstanding.value,
                    icon: FontAwesomeIcons.handHoldingDollar,
                    color: dangerRed,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Obx(
                  () => _buildKPICard(
                    title: "Total Payables (Liabilities)",
                    value: controller.totalMarketPayable.value,
                    icon: FontAwesomeIcons.fileInvoiceDollar,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: scaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => controller.searchDebtors(val),
                    onSubmitted: (val) => controller.searchDebtors(val),
                    decoration: InputDecoration(
                      hintText: "Search name, description, or phone...",
                      prefixIcon: const Icon(Icons.search, color: textLight),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: textLight,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          controller.searchDebtors('');
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed:
                    () => controller.searchDebtors(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(50, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Search",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS (Repair & Delete)
  // ==========================================
  void _confirmRepairDialog() {
    Get.defaultDialog(
      title: "Upgrade Search Data",
      middleText:
          "This will update all existing debtors in the database to support the new multi-word description search. This only needs to be done once.",
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
              Get.back(); // close dialog
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

  // ==========================================
  // 4. PAGINATION FOOTER
  // ==========================================
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
  // WIDGET HELPERS
  // ==========================================
  Widget _buildKPICard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bdCurrency.format(value),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFE5E7EB),
        border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB))),
      ),
      child: Row(
        children: [
          _colHeader("CLIENT DETAILS", flex: 3),
          _colHeader("CONTACT INFO", flex: 2),
          _colHeader("BALANCE STATUS", flex: 2, align: TextAlign.right),
          _colHeader("LOCATION", flex: 2),
          // Actions Header Column
          Container(
            width: 70,
            alignment: Alignment.center,
            child: const Text(
              "ACTION",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
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
          fontWeight: FontWeight.bold,
          color: textLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableRow(dynamic debtor) {
    return InkWell(
      onTap:
          () => Get.to(() => Debatordetails(id: debtor.id, name: debtor.name)),
      hoverColor: Colors.grey.shade50,
      child: Container(
        color: surfaceWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // 1. Client Details
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryColor.withOpacity(0.1),
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
                            fontWeight: FontWeight.w600,
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
                              fontSize: 11,
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

            // 2. Contact Info
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: textLight),
                      const SizedBox(width: 4),
                      Text(
                        debtor.phone,
                        style: const TextStyle(color: textDark, fontSize: 13),
                      ),
                    ],
                  ),
                  if (debtor.nid.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "NID: ${debtor.nid}",
                        style: const TextStyle(color: textLight, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Balance Status (Live Stream)
            Expanded(
              flex: 2,
              child: StreamBuilder<double>(
                stream: controller.getLiveBalance(debtor.id),
                initialData: debtor.balance,
                builder: (context, snapshot) {
                  double bal = snapshot.data ?? 0.0;
                  bool isDue = bal > 0;

                  return Row(
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
                                  ? dangerRed.withOpacity(0.1)
                                  : successGreen.withOpacity(0.1),
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
                  );
                },
              ),
            ),

            // 4. Location
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

            // 5. Action Menu (Updated)
            SizedBox(
              width: 70,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: textLight),
                tooltip: "Options",
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  if (value == 'view') {
                    Get.to(
                      () => Debatordetails(id: debtor.id, name: debtor.name),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteDebtor(debtor);
                  }
                },
                itemBuilder:
                    (context) => [
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: dangerRed, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Delete Debtor",
                              style: TextStyle(color: dangerRed),
                            ),
                          ],
                        ),
                      ),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: 40,
              color: textLight.withOpacity(0.5),
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
}