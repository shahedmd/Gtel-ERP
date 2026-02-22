// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

          // List
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

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.vendors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _VendorCard(
                    vendor: controller.vendors[index],
                    controller: controller,
                  );
                },
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          onPressed: () => ctrl.addVendor(nameC.text, contactC.text),
          child: const Text(
            "Create Vendor",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorModel vendor;
  final VendorController controller;
  const _VendorCard({required this.vendor, required this.controller});

  @override
  Widget build(BuildContext context) {
    Color color =
        vendor.totalDue > 0
            ? AppTheme.danger
            : (vendor.totalDue < 0 ? AppTheme.success : AppTheme.textMuted);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          controller.loadHistoryInitial(vendor.docId!);
          Get.to(
            () => VendorDetailPage(vendor: vendor, controller: controller),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.bgGrey,
                radius: 24,
                child: Text(
                  vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : "?",
                  style: const TextStyle(
                    color: AppTheme.darkSlate,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vendor.contact,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "BDT ${vendor.formattedDue}",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _statusBadge(vendor.totalDue),
                ],
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

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
            Text(
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
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Balance Summary
          _buildBalanceSummary(),

          // 2. Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: "ADD BILL",
                    icon: Icons.post_add,
                    color: AppTheme.danger,
                    // 'Purchase' usually increases debt (Credit)
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.purchase,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: "MAKE PAYMENT",
                    icon: Icons.send,
                    color: AppTheme.success,
                    // 'Payment' decreases debt (Debit) and reduces Cash/Bank
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.payment,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Filters
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

          // 4. Headers
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

          // 5. List
          Expanded(child: _buildTransactionList()),

          // 6. Pagination
          _buildHistoryPagination(controller),
        ],
      ),
    );
  }

  // --- WIDGETS ---

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
            (_, __) => const Divider(height: 1, color: AppTheme.border),
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
                  child: Text(
                    DateFormat('dd MMM yyyy').format(tx.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textDark,
                    ),
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
                      // Show method if it's a payment
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
                          (isCredit || isIncoming)
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
                            (isCredit || isIncoming)
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
                          (isCredit || isIncoming)
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

  // =========================================================================
  // UPDATED: ADD TRANSACTION FORM
  // Now includes "Payment Method" Dropdown
  // =========================================================================
  void _openTransactionForm(BuildContext context, TransactionMode mode) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    Rx<DateTime> selectedDate = DateTime.now().obs;

    // NEW: Payment Method Selection
    final List<String> methods = ['Cash', 'Bank', 'Bkash', 'Nagad'];
    RxString selectedMethod = 'Cash'.obs;

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
                  mode == TransactionMode.purchase
                      ? "Add Vendor Bill"
                      : "Add Payment",
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

            // Amount
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

            // Date Picker
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) selectedDate.value = d;
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Date",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Obx(
                  () => Text(
                    DateFormat('dd MMM, yyyy').format(selectedDate.value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // NEW: Payment Method Dropdown
            // Only show if we are making a payment (DEBIT)
            // Bills (CREDIT) usually don't involve cash movement unless specified, defaults to Cash if needed
            if (mode == TransactionMode.payment)
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

            // Note
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

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      mode == TransactionMode.purchase
                          ? AppTheme.danger
                          : AppTheme.success,
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
                    type: mode == TransactionMode.purchase ? 'CREDIT' : 'DEBIT',
                    amount: double.parse(amountC.text),
                    date: selectedDate.value,
                    notes: noteC.text,
                    // Pass the selected method here
                    paymentMethod: selectedMethod.value,
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

  // --- EDIT TRANSACTION ---
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
              if (d != null) editDate.value = d;
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Date",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Obx(
                () => Text(DateFormat('dd MMM, yyyy').format(editDate.value)),
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
          "This will remove the transaction and reverse the balance impact. Cannot be undone.",
      textConfirm: "DELETE",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.danger,
      onConfirm: () => controller.deleteTransaction(vendor.docId!, tx),
    );
  }

  Future<void> _generatePDF(BuildContext context) async {
    final pdf = pw.Document();
    final list = controller.currentTransactions;
    pdf.addPage(
      pw.MultiPage(
        build:
            (ctx) => [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Statement: ${vendor.name}",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Text(
                  "Generated on: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                ),
              ),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
                headers: ["Date", "Description", "Type", "Amount"],
                data:
                    list
                        .map(
                          (e) => [
                            DateFormat('dd/MM/yyyy').format(e.date),
                            e.shipmentName ?? e.notes ?? "-",
                            e.isIncomingCash
                                ? "ADVANCE"
                                : (e.type == 'CREDIT' ? "BILL" : "PAYMENT"),
                            e.formattedAmount,
                          ],
                        )
                        .toList(),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (f) => pdf.save(),
      name: 'Statement_${vendor.name}.pdf',
    );
  }
}

// Helpers
enum TransactionMode { purchase, payment }

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
    icon: Icon(icon, size: 18),
    label: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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