// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';

// ==========================================
// 1. ERP THEME CONFIGURATION
// ==========================================
class AppTheme {
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color primary = Color(0xFF2563EB);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}

// ==========================================
// 2. VENDOR LIST PAGE (DASHBOARD)
// ==========================================
class VendorPage extends StatelessWidget {
  const VendorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VendorController controller = Get.put(VendorController());

    return Scaffold(
      backgroundColor: AppTheme.bgGrey,
      appBar: AppBar(
        title: const Text(
          "Vendor Accounts",
          style: TextStyle(
            color: AppTheme.darkSlate,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "NEW VENDOR",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddVendorDialog(controller),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => controller.searchVendors(val),
              decoration: InputDecoration(
                hintText: "Search vendors...",
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ),

          // Datatable (FULL WIDTH FIX)
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.vendors.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_mall_directory_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "No vendors found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Card(
                elevation: 0,
                margin: EdgeInsets.zero, // REMOVED MARGIN FOR FULL WIDTH
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, // Made edges straight
                  side: BorderSide(color: AppTheme.border),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          // FORCES TABLE TO STRETCH TO SCREEN WIDTH
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              AppTheme.bgGrey,
                            ),
                            columnSpacing: 25,
                            dataRowHeight: 65,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Company Name',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Contact',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Balance (BDT)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Status',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Actions',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows:
                                controller.vendors.map((vendor) {
                                  Color color =
                                      vendor.totalDue > 0
                                          ? AppTheme.danger
                                          : (vendor.totalDue < 0
                                              ? AppTheme.success
                                              : AppTheme.textMuted);

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: AppTheme
                                                  .darkSlate
                                                  .withOpacity(0.1),
                                              child: Text(
                                                vendor.name.isNotEmpty
                                                    ? vendor.name[0]
                                                        .toUpperCase()
                                                    : "?",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              vendor.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          vendor.contact,
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          vendor.formattedDue,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      DataCell(_statusBadge(vendor.totalDue)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Colors.blueGrey,
                                                size: 20,
                                              ),
                                              tooltip: "Edit Vendor",
                                              onPressed:
                                                  () => _showEditVendorDialog(
                                                    controller,
                                                    vendor,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.danger,
                                                size: 20,
                                              ),
                                              tooltip: "Delete Vendor",
                                              onPressed:
                                                  () =>
                                                      _showDeleteVendorConfirm(
                                                        controller,
                                                        vendor,
                                                      ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              onPressed: () {
                                                controller.loadHistoryInitial(
                                                  vendor.docId!,
                                                );
                                                Get.to(
                                                  () => VendorDetailPage(
                                                    vendor: vendor,
                                                    controller: controller,
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                "Ledger",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),

          // Pagination Footer
          _buildPaginationFooter(controller),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(VendorController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Obx(
            () => Text(
              "Page ${controller.currentVendorPage.value}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Row(
            children: [
              Obx(
                () => IconButton(
                  onPressed:
                      controller.currentVendorPage.value > 1
                          ? () => controller.previousVendorPage()
                          : null,
                  icon: const Icon(Icons.chevron_left),
                  color: AppTheme.darkSlate,
                ),
              ),
              Obx(
                () => IconButton(
                  onPressed:
                      controller.hasMoreVendors.value
                          ? () => controller.nextVendorPage()
                          : null,
                  icon: const Icon(Icons.chevron_right),
                  color: AppTheme.darkSlate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(double due) {
    String text;
    Color bg;
    Color fg;

    if (due > 0) {
      text = "PAYABLE";
      bg = AppTheme.danger.withOpacity(0.1);
      fg = AppTheme.danger;
    } else if (due < 0) {
      text = "ADVANCE";
      bg = AppTheme.success.withOpacity(0.1);
      fg = AppTheme.success;
    } else {
      text = "SETTLED";
      bg = AppTheme.textMuted.withOpacity(0.1);
      fg = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showAddVendorDialog(VendorController ctrl) {
    final nameC = TextEditingController();
    final contactC = TextEditingController();
    Get.defaultDialog(
      title: "Add Vendor",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.all(24),
      radius: 12,
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Company Name",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: contactC,
            decoration: const InputDecoration(
              labelText: "Contact / Phone",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        ],
      ),
      confirm: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkSlate,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {
            if (nameC.text.trim().isEmpty) return;
            ctrl.addVendor(nameC.text, contactC.text);
          },
          child: const Text(
            "Create Vendor",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _showEditVendorDialog(VendorController ctrl, VendorModel vendor) {
    final nameC = TextEditingController(text: vendor.name);
    final contactC = TextEditingController(text: vendor.contact);
    Get.defaultDialog(
      title: "Edit Vendor",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.all(24),
      radius: 12,
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Company Name",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: contactC,
            decoration: const InputDecoration(
              labelText: "Contact / Phone",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        ],
      ),
      confirm: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {
            if (nameC.text.trim().isEmpty) return;
            ctrl.updateVendor(
              vendorId: vendor.docId!,
              name: nameC.text,
              contact: contactC.text,
            );
          },
          child: const Text(
            "Save Changes",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _showDeleteVendorConfirm(VendorController ctrl, VendorModel vendor) {
    Get.defaultDialog(
      title: "Delete Vendor?",
      middleText:
          "Are you sure you want to delete ${vendor.name}? This action requires all transactions to be deleted first.",
      textConfirm: "DELETE",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.danger,
      onConfirm: () {
        Get.back(); // close dialog
        ctrl.deleteVendor(vendor.docId!);
      },
    );
  }
}

// ==========================================
// 3. VENDOR DETAIL PAGE (LEDGER)
// ==========================================
class VendorDetailPage extends StatelessWidget {
  final VendorModel vendor;
  final VendorController controller;

  const VendorDetailPage({
    super.key,
    required this.vendor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vendor.name,
              style: const TextStyle(
                color: AppTheme.darkSlate,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Vendor Ledger",
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: "Print Statement",
            // Pass the whole vendor object so we have the ID to fetch all data
            onPressed: () => controller.generateVendorReport(vendor),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceSummary(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: "ADD BILL",
                    icon: Icons.post_add,
                    color: AppTheme.danger,
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.purchase,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: "PAYMENT",
                    icon: Icons.send,
                    color: AppTheme.success,
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.payment,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: "ADVANCE",
                    icon: Icons.account_balance_wallet,
                    color: AppTheme.primary,
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.advance,
                        ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterButton(label: "All", value: "All", ctrl: controller),
                const SizedBox(width: 8),
                _FilterButton(
                  label: "Bills",
                  value: "CREDIT",
                  ctrl: controller,
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  label: "Payments",
                  value: "DEBIT",
                  ctrl: controller,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    "DATE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    "DESCRIPTION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TYPE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "AMOUNT",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ),

          Expanded(child: _buildTransactionList()),

          _buildHistoryPagination(controller),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary() {
    return Container(
      width: double.infinity,
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Obx(() {
        final liveVendor = controller.vendors.firstWhere(
          (v) => v.docId == vendor.docId,
          orElse: () => vendor,
        );
        Color color =
            liveVendor.totalDue > 0
                ? AppTheme.danger
                : (liveVendor.totalDue < 0
                    ? AppTheme.success
                    : AppTheme.textDark);

        return Column(
          children: [
            const Text(
              "NET OUTSTANDING BALANCE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "BDT ${liveVendor.formattedDue}",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                liveVendor.totalDue > 0
                    ? "You owe money"
                    : (liveVendor.totalDue < 0 ? "Advance Paid" : "Settled"),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTransactionList() {
    return Obx(() {
      if (controller.isHistoryLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.currentTransactions.isEmpty) {
        return const Center(
          child: Text(
            "No transactions found",
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.currentTransactions.length,
        separatorBuilder:
            (_, _) => const Divider(height: 1, color: AppTheme.border),
        itemBuilder: (context, index) {
          final tx = controller.currentTransactions[index];
          bool isCredit = tx.type == 'CREDIT';
          bool isIncoming = tx.isIncomingCash;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yy').format(tx.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(tx.date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tx.shipmentName != null)
                        Text(
                          tx.shipmentName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        tx.notes ?? "-",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isCredit && !isIncoming && tx.paymentMethod != null)
                        Text(
                          "Paid via: ${tx.paymentMethod}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isCredit && !isIncoming)
                              ? AppTheme.danger.withOpacity(0.1)
                              : AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isIncoming ? "ADVANCE" : (isCredit ? "BILL" : "PAYMENT"),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            (isCredit && !isIncoming)
                                ? AppTheme.danger
                                : AppTheme.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    tx.formattedAmount,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color:
                          (isCredit && !isIncoming)
                              ? AppTheme.danger
                              : AppTheme.success,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _showEditTransactionDialog(context, tx),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showDeleteConfirm(context, tx),
                        child: const Icon(
                          Icons.delete,
                          size: 16,
                          color: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildHistoryPagination(VendorController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => Text(
              "Page ${ctrl.currentTransPage.value}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              Obx(
                () => IconButton(
                  onPressed:
                      ctrl.currentTransPage.value > 1
                          ? () => ctrl.previousHistoryPage()
                          : null,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 16),
              Obx(
                () => IconButton(
                  onPressed:
                      ctrl.hasMoreTrans.value
                          ? () => ctrl.nextHistoryPage()
                          : null,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openTransactionForm(BuildContext context, TransactionMode mode) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    Rx<DateTime> selectedDate = DateTime.now().obs;

    final List<String> methods = ['Cash', 'Bank', 'Bkash', 'Nagad'];
    RxString selectedMethod = 'Cash'.obs;

    String title = "";
    Color themeColor;
    if (mode == TransactionMode.purchase) {
      title = "Add Vendor Bill";
      themeColor = AppTheme.danger;
    } else if (mode == TransactionMode.payment) {
      title = "Make Payment";
      themeColor = AppTheme.success;
    } else {
      title = "Receive Advance/Refund";
      themeColor = AppTheme.primary;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            TextField(
              controller: amountC,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Amount",
                prefixText: "BDT ",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: AppTheme.bgGrey,
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) {
                    selectedDate.value = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t.hour,
                      t.minute,
                    );
                  } else {
                    final now = DateTime.now();
                    selectedDate.value = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      now.hour,
                      now.minute,
                    );
                  }
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Date & Time",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Obx(
                  () => Text(
                    DateFormat(
                      'dd MMM, yyyy - hh:mm a',
                    ).format(selectedDate.value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (mode == TransactionMode.payment ||
                mode == TransactionMode.advance)
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMethod.value,
                    decoration: InputDecoration(
                      labelText: "Payment Method",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.payment),
                    ),
                    items:
                        methods
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) selectedMethod.value = val;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            TextField(
              controller: noteC,
              decoration: InputDecoration(
                labelText: "Note / Description",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (amountC.text.isEmpty) return;
                  controller.addTransaction(
                    vendorId: vendor.docId!,
                    vendorName: vendor.name,
                    type:
                        mode == TransactionMode.purchase
                            ? 'CREDIT'
                            : (mode == TransactionMode.payment
                                ? 'DEBIT'
                                : 'CREDIT'),
                    amount: double.parse(amountC.text),
                    date: selectedDate.value,
                    notes: noteC.text,
                    paymentMethod:
                        (mode == TransactionMode.payment ||
                                mode == TransactionMode.advance)
                            ? selectedMethod.value
                            : null,
                    isIncomingCash: mode == TransactionMode.advance,
                  );
                },
                child: const Text(
                  "CONFIRM TRANSACTION",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showEditTransactionDialog(BuildContext context, VendorTransaction tx) {
    final amountC = TextEditingController(text: tx.amount.toString());
    final noteC = TextEditingController(text: tx.notes);
    Rx<DateTime> editDate = tx.date.obs;

    Get.defaultDialog(
      title: "Edit Transaction",
      contentPadding: const EdgeInsets.all(20),
      radius: 10,
      content: Column(
        children: [
          TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: editDate.value,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (t != null) {
                  editDate.value = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    t.hour,
                    t.minute,
                  );
                } else {
                  editDate.value = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    DateTime.now().hour,
                    DateTime.now().minute,
                  );
                }
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Date",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Obx(
                () => Text(
                  DateFormat('dd MMM, yyyy - hh:mm a').format(editDate.value),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteC,
            decoration: const InputDecoration(
              labelText: "Note",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
        onPressed: () {
          controller.updateTransaction(
            vendorId: vendor.docId!,
            oldTrans: tx,
            newAmount: double.tryParse(amountC.text) ?? 0,
            newDate: editDate.value,
            newNotes: noteC.text,
          );
        },
        child: const Text("Update", style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, VendorTransaction tx) {
    Get.defaultDialog(
      title: "Delete Transaction?",
      middleText:
          "This will remove the transaction, reverse the balance impact, and adjust the Cash Ledger.",
      textConfirm: "DELETE",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.danger,
      onConfirm: () => controller.deleteTransaction(vendor.docId!, tx),
    );
  }
}

// Helpers
enum TransactionMode { purchase, payment, advance }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 2,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  final String label;
  final String value;
  final VendorController ctrl;
  const _FilterButton({
    required this.label,
    required this.value,
    required this.ctrl,
  });
  @override
  Widget build(BuildContext context) => Obx(
    () => InkWell(
      onTap: () => ctrl.setTransactionFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              ctrl.currentTransFilter.value == value
                  ? AppTheme.darkSlate
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                ctrl.currentTransFilter.value == value
                    ? AppTheme.darkSlate
                    : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color:
                ctrl.currentTransFilter.value == value
                    ? Colors.white
                    : AppTheme.textMuted,
          ),
        ),
      ),
    ),
  );
}
