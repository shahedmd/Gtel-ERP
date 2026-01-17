// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ADJUST IMPORTS TO MATCH YOUR FOLDER STRUCTURE
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';

// ==========================================
// 1. ERP THEME CONFIGURATION
// ==========================================
class AppTheme {
  // Core Colors
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);

  // Semantic Colors
  static const Color creditRed = Color(
    0xFFEF4444,
  ); // Liability Increases (Bill)
  static const Color debitGreen = Color(
    0xFF10B981,
  ); // Liability Decreases (Payment)
  static const Color advancePurple = Color(
    0xFF8B5CF6,
  ); // Cash In (Advance/Refund)
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Text Styles
  static TextStyle get title => const TextStyle(
    color: darkSlate,
    fontWeight: FontWeight.w800,
    fontSize: 22,
    letterSpacing: -0.5,
  );

  static TextStyle get label => const TextStyle(
    color: textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get value => const TextStyle(
    color: textDark,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
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
        title: Text("Vendor Management", style: AppTheme.title),
        backgroundColor: AppTheme.bgGrey,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.darkSlate),
            onPressed: () => controller.bindVendors(),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search vendor...",
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.white,
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
              if (controller.vendors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No Vendors Found",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.vendors.length,
                itemBuilder: (context, index) {
                  return _VendorCard(
                    vendor: controller.vendors[index],
                    controller: controller,
                  );
                },
              );
            }),
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
      titlePadding: const EdgeInsets.only(top: 20),
      contentPadding: const EdgeInsets.all(20),
      radius: 10,
      content: Column(
        children: [
          _AppTextField(
            controller: nameC,
            label: "Company Name",
            icon: Icons.business,
          ),
          const SizedBox(height: 15),
          _AppTextField(
            controller: contactC,
            label: "Contact Number",
            icon: Icons.phone,
          ),
        ],
      ),
      confirm: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkSlate,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => ctrl.addVendor(nameC.text, contactC.text),
          child: const Text(
            "SAVE",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    // Red if positive (We owe), Green if negative (Advance given)
    final color =
        vendor.totalDue > 0
            ? AppTheme.creditRed
            : (vendor.totalDue < 0 ? AppTheme.debitGreen : AppTheme.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          controller.fetchHistory(vendor.docId!);
          Get.to(
            () => VendorDetailPage(vendor: vendor, controller: controller),
          );
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.darkSlate,
          child: Text(
            vendor.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(vendor.name, style: AppTheme.value.copyWith(fontSize: 16)),
        subtitle: Text(
          vendor.contact,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("Balance", style: AppTheme.label),
            const SizedBox(height: 2),
            Text(
              NumberFormat.simpleCurrency(
                name: 'BDT ',
                decimalDigits: 0,
              ).format(vendor.totalDue),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. VENDOR DETAIL PAGE (LEDGER & ACTIONS)
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              vendor.contact,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _generatePDF(context),
            tooltip: "Download Statement",
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER: BALANCE ---
          _buildBalanceHeader(),

          // --- ACTION GRID (3 BUTTONS) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // 1. BILL (Purchase)
                Expanded(
                  child: _ActionButton(
                    label: "Purchase",
                    sub: "Bill Entry",
                    icon: Icons.receipt_long,
                    color: AppTheme.creditRed,
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.purchase,
                        ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. PAYMENT (Out)
                Expanded(
                  child: _ActionButton(
                    label: "Payment",
                    sub: "Send Cash",
                    icon: Icons.send,
                    color: AppTheme.debitGreen,
                    onTap:
                        () => _openTransactionForm(
                          context,
                          TransactionMode.payment,
                        ),
                  ),
                ),
                const SizedBox(width: 10),

                // 3. ADVANCE (In) - NEW!
                Expanded(
                  child: _ActionButton(
                    label: "Receive",
                    sub: "Adv/Refund",
                    icon: Icons.download,
                    color: AppTheme.advancePurple,
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

          // --- LEDGER LIST ---
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text("RECENT TRANSACTIONS", style: AppTheme.label),
                  ),
                  Expanded(
                    child: Obx(() {
                      if (controller.currentTransactions.isEmpty) {
                        return const Center(
                          child: Text(
                            "No history available",
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: controller.currentTransactions.length,
                        separatorBuilder:
                            (_, __) => const Divider(
                              height: 1,
                              indent: 70,
                              color: AppTheme.bgGrey,
                            ),
                        itemBuilder:
                            (context, index) => _TransactionTile(
                              tx: controller.currentTransactions[index],
                            ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text("OUTSTANDING BALANCE", style: AppTheme.label),
          const SizedBox(height: 8),
          Obx(() {
            final liveVendor = controller.vendors.firstWhere(
              (v) => v.docId == vendor.docId,
              orElse: () => vendor,
            );
            return Text(
              NumberFormat.simpleCurrency(
                name: 'BDT ',
                decimalDigits: 0,
              ).format(liveVendor.totalDue),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color:
                    liveVendor.totalDue > 0
                        ? AppTheme.creditRed
                        : AppTheme.debitGreen,
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- LOGIC: TRANSACTION DIALOG ---
  void _openTransactionForm(BuildContext context, TransactionMode mode) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final refC = TextEditingController();
    final methodC = TextEditingController(text: "Cash");
    final date = DateTime.now().obs;

    String title;
    Color color;
    IconData icon;

    switch (mode) {
      case TransactionMode.purchase:
        title = "Record Purchase (Bill)";
        color = AppTheme.creditRed;
        icon = Icons.shopping_cart;
        break;
      case TransactionMode.payment:
        title = "Record Payment (Out)";
        color = AppTheme.debitGreen;
        icon = Icons.arrow_outward;
        break;
      case TransactionMode.advance:
        title = "Receive Advance (In)";
        color = AppTheme.advancePurple;
        icon = Icons.arrow_downward;
        break;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: AppTheme.title.copyWith(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 20),

              // Inputs
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _AppTextField(
                      controller: amountC,
                      label: "Amount",
                      icon: Icons.attach_money,
                      isNumber: true,
                      autoFocus: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: date.value,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) date.value = d;
                      },
                      child: Obx(
                        () => Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('dd/MM').format(date.value),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hide Payment Method for Purchase (usually just Bill Credit)
              if (mode != TransactionMode.purchase)
                _AppTextField(
                  controller: methodC,
                  label: "Payment Method (Cash/Bank/Bkash)",
                  icon: Icons.account_balance_wallet,
                ),

              if (mode == TransactionMode.purchase)
                _AppTextField(
                  controller: refC,
                  label: "Shipment Ref / Invoice #",
                  icon: Icons.description,
                ),

              const SizedBox(height: 16),
              _AppTextField(
                controller: noteC,
                label: "Notes / Remarks",
                icon: Icons.note,
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (amountC.text.isEmpty) return;
                    Get.back();

                    controller.addTransaction(
                      vendorId: vendor.docId!,
                      vendorName: vendor.name,
                      type:
                          mode == TransactionMode.payment ? 'DEBIT' : 'CREDIT',
                      amount: double.parse(amountC.text),
                      date: date.value,
                      notes: noteC.text,
                      paymentMethod: methodC.text,
                      shipmentName: refC.text,
                      // KEY LOGIC CONNECTION:
                      isIncomingCash: mode == TransactionMode.advance,
                    );
                  },
                  child: Text(
                    "CONFIRM ENTRY",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10), // Safe area
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // --- PDF GENERATION ---
  Future<void> _generatePDF(BuildContext context) async {
    final pdf = pw.Document();
    final list = List<VendorTransaction>.from(controller.currentTransactions);
    list.sort(
      (a, b) => a.date.compareTo(b.date),
    ); // Oldest first for ledger calc

    double balance = 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Text("VENDOR LEDGER: ${vendor.name.toUpperCase()}"),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: [
                  "Date",
                  "Description",
                  "Debit (-)",
                  "Credit (+)",
                  "Balance",
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                ),
                data:
                    list.map((t) {
                      // Calculate running balance
                      // Credit (Bill) = Adds to Due
                      // Advance (Incoming Cash) = Adds to Due (Liability)
                      // Debit (Payment) = Reduces Due
                      bool isLiabilityIncrease = t.type == 'CREDIT';

                      if (isLiabilityIncrease) {
                        balance += t.amount;
                      } else {
                        balance -= t.amount;
                      }

                      // Description String
                      String desc = t.shipmentName ?? t.type;
                      if (t.isIncomingCash) desc = "ADVANCE RECEIVED";
                      if (t.notes != null && t.notes!.isNotEmpty) {
                        desc += "\n(${t.notes})";
                      }

                      return [
                        DateFormat('yyyy-MM-dd').format(t.date),
                        desc,
                        !isLiabilityIncrease
                            ? t.amount.toStringAsFixed(0)
                            : "-",
                        isLiabilityIncrease ? t.amount.toStringAsFixed(0) : "-",
                        balance.toStringAsFixed(0),
                      ];
                    }).toList(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                cellAlignments: {
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Closing Balance: $balance",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }
}

// ==========================================
// 4. HELPER WIDGETS
// ==========================================

enum TransactionMode { purchase, payment, advance }

class _ActionButton extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                sub,
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final VendorTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    // Determine visuals
    final bool isBill = tx.type == 'CREDIT' && !tx.isIncomingCash;
    final bool isAdvance = tx.isIncomingCash;

    Color color;
    IconData icon;
    String title;
    String sign;

    if (isAdvance) {
      color = AppTheme.advancePurple;
      icon = Icons.download;
      title = "Advance Received";
      sign = "+";
    } else if (isBill) {
      color = AppTheme.creditRed;
      icon = Icons.receipt_long;
      title = tx.shipmentName ?? "Purchase Bill";
      sign = "+";
    } else {
      color = AppTheme.debitGreen;
      icon = Icons.arrow_outward;
      title = "Payment Sent";
      sign = "-";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: AppTheme.value),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd MMM, hh:mm a').format(tx.date),
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (tx.notes != null && tx.notes!.isNotEmpty)
            Text(
              tx.notes!,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textDark.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: Text(
        "$sign ${NumberFormat.compact().format(tx.amount)}",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;
  final bool autoFocus;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumber = false,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autoFocus,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.darkSlate, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.bgGrey,
      ),
    );
  }
}
