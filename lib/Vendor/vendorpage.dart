// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';

// ==========================================
// 1. ERP THEME CONFIGURATION
// ==========================================
class AppTheme {
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color bgGrey = Color(0xFFF1F5F9);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFCBD5E1);
  static const Color primary = Color(0xFF3B82F6);
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
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.darkSlate,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW VENDOR", style: TextStyle(color: Colors.white)),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
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
                return const Center(child: Text("No vendors found"));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.vendors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                ),
              ),
              Obx(
                () => IconButton(
                  onPressed:
                      controller.hasMoreVendors.value
                          ? () => controller.nextVendorPage()
                          : null,
                  icon: const Icon(Icons.chevron_right),
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
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Company Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: contactC,
            decoration: const InputDecoration(
              labelText: "Contact",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkSlate),
        onPressed: () => ctrl.addVendor(nameC.text, contactC.text),
        child: const Text("Create", style: TextStyle(color: Colors.white)),
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
            : (vendor.totalDue < 0 ? AppTheme.primary : AppTheme.success);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ListTile(
        onTap: () {
          controller.loadHistoryInitial(vendor.docId!);
          Get.to(
            () => VendorDetailPage(vendor: vendor, controller: controller),
          );
        },
        leading: CircleAvatar(
          backgroundColor: AppTheme.bgGrey,
          child: Text(
            vendor.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppTheme.darkSlate,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          vendor.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(vendor.contact),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "BDT ${vendor.formattedDue}",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(vendor.status, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. VENDOR DETAIL PAGE (ERP TABLE)
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
        title: Text(
          vendor.name,
          style: const TextStyle(color: AppTheme.darkSlate),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance Header (Live Update via Obx)
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.white,
            width: double.infinity,
            child: Obx(() {
              final liveVendor = controller.vendors.firstWhere(
                (v) => v.docId == vendor.docId,
                orElse: () => vendor,
              );
              Color color =
                  liveVendor.totalDue > 0
                      ? AppTheme.danger
                      : (liveVendor.totalDue < 0
                          ? AppTheme.primary
                          : AppTheme.success);
              return Column(
                children: [
                  const Text(
                    "Current Balance",
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  Text(
                    "BDT ${liveVendor.formattedDue}",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              );
            }),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    "Add Bill",
                    Icons.receipt,
                    AppTheme.danger,
                    () =>
                        _openTransactionForm(context, TransactionMode.purchase),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    "Payment",
                    Icons.send,
                    AppTheme.success,
                    () =>
                        _openTransactionForm(context, TransactionMode.payment),
                  ),
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterButton("All", "All", controller),
                const SizedBox(width: 8),
                _FilterButton("Bills", "CREDIT", controller),
                const SizedBox(width: 8),
                _FilterButton("Payments", "DEBIT", controller),
              ],
            ),
          ),

          // ERP Table
          Expanded(child: _buildTransactionTable()),

          // History Pagination
          _buildHistoryPagination(controller),
        ],
      ),
    );
  }

  Widget _buildTransactionTable() {
    return Obx(() {
      if (controller.isHistoryLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.currentTransactions.isEmpty) {
        return const Center(child: Text("No transactions"));
      }

      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
            columns: const [
              DataColumn(label: Text("Date")),
              DataColumn(label: Text("Description")),
              DataColumn(label: Text("Type")),
              DataColumn(label: Text("Amount",)),
            ],
            rows:
                controller.currentTransactions.map((tx) {
                  bool isCredit = tx.type == 'CREDIT' || tx.isIncomingCash;
                  return DataRow(
                    cells: [
                      DataCell(Text(DateFormat('dd-MMM').format(tx.date))),
                      DataCell(Text(tx.shipmentName ?? tx.notes ?? "-")),
                      DataCell(
                        Text(
                          tx.isIncomingCash
                              ? "ADVANCE"
                              : (isCredit ? "BILL" : "PAYMENT"),
                          style: TextStyle(
                            color:
                                isCredit ? AppTheme.danger : AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          tx.formattedAmount,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      );
    });
  }

  Widget _buildHistoryPagination(VendorController ctrl) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(() => Text("Page ${ctrl.currentTransPage.value}")),
          Row(
            children: [
              Obx(
                () => IconButton(
                  onPressed:
                      ctrl.currentTransPage.value > 1
                          ? () => ctrl.previousHistoryPage()
                          : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Obx(
                () => IconButton(
                  onPressed:
                      ctrl.hasMoreTrans.value
                          ? () => ctrl.nextHistoryPage()
                          : null,
                  icon: const Icon(Icons.chevron_right),
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
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode == TransactionMode.purchase ? "Add Bill" : "Add Payment",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
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
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkSlate,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (amountC.text.isEmpty) return;
                Get.back();
                controller.addTransaction(
                  vendorId: vendor.docId!,
                  vendorName: vendor.name,
                  type: mode == TransactionMode.purchase ? 'CREDIT' : 'DEBIT',
                  amount: double.parse(amountC.text),
                  date: DateTime.now(),
                  notes: noteC.text,
                );
              },
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePDF(BuildContext context) async {
    final pdf = pw.Document();
    final list = controller.currentTransactions;
    pdf.addPage(
      pw.MultiPage(
        build:
            (ctx) => [
              pw.Header(level: 0, child: pw.Text("Statement: ${vendor.name}")),
              pw.Table.fromTextArray(
                headers: ["Date", "Desc", "Amount"],
                data:
                    list
                        .map(
                          (e) => [
                            DateFormat('dd/MM').format(e.date),
                            e.notes ?? "-",
                            e.amount.toString(),
                          ],
                        )
                        .toList(),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }
}

// Helpers
enum TransactionMode { purchase, payment }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withOpacity(0.1),
      foregroundColor: color,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 15),
    ),
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );
}

class _FilterButton extends StatelessWidget {
  final String label;
  final String value;
  final VendorController ctrl;
  const _FilterButton(this.label, this.value, this.ctrl);
  @override
  Widget build(BuildContext context) => Obx(
    () => InkWell(
      onTap: () => ctrl.setTransactionFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              ctrl.currentTransFilter.value == value
                  ? AppTheme.darkSlate
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
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