// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Import your controller and model
import 'package:gtel_erp/Vendor/vendorcontroller.dart';
import 'package:gtel_erp/Vendor/vendormodel.dart';

// ==========================================
// 1. ERP THEME CONFIGURATION
// ==========================================
class AppTheme {
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(
    0xFFF3F4F6,
  ); // Slightly lighter for contrast
  static const Color textMuted = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);

  static const Color creditRed = Color(0xFFEF4444); // Bills/Due
  static const Color debitGreen = Color(0xFF10B981); // Payments
  static const Color white = Colors.white;

  static TextStyle get title => const TextStyle(
    color: darkSlate,
    fontWeight: FontWeight.bold,
    fontSize: 18,
  );

  static TextStyle get subTitle =>
      const TextStyle(color: textMuted, fontSize: 12);
}

// ==========================================
// 2. VENDOR LIST PAGE (POS STYLE)
// ==========================================
class VendorPage extends StatelessWidget {
  const VendorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VendorController controller = Get.put(VendorController());

    return Scaffold(
      backgroundColor: AppTheme.bgGrey,
      appBar: AppBar(
        title: Text("VENDOR LEDGER", style: AppTheme.title),
        backgroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.darkSlate),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.activeAccent),
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
          // Search/Filter Bar Placeholder (Visual only for POS feel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search vendors...",
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bgGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          Expanded(
            child: Obx(() {
              if (controller.vendors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront, size: 60, color: Colors.grey[300]),
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
                padding: const EdgeInsets.all(16),
                itemCount: controller.vendors.length,
                itemBuilder: (context, index) {
                  final vendor = controller.vendors[index];
                  return _buildVendorCard(vendor, controller);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(VendorModel vendor, VendorController controller) {
    final bool hasDue = vendor.totalDue > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            controller.fetchHistory(vendor.docId!);
            Get.to(
              () => VendorDetailPage(vendor: vendor, controller: controller),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar / Initials
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.darkSlate.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      vendor.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 12,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(vendor.contact, style: AppTheme.subTitle),
                        ],
                      ),
                    ],
                  ),
                ),

                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Current Due",
                      style: AppTheme.subTitle.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat.simpleCurrency(
                        name: '৳',
                        decimalDigits: 0,
                      ).format(vendor.totalDue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            hasDue ? AppTheme.creditRed : AppTheme.debitGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddVendorDialog(VendorController ctrl) {
    final nameC = TextEditingController();
    final contactC = TextEditingController();
    Get.defaultDialog(
      title: "Add Vendor",
      titleStyle: AppTheme.title,
      contentPadding: const EdgeInsets.all(20),
      radius: 10,
      content: Column(
        children: [
          _buildTextField(nameC, "Company/Vendor Name", Icons.business),
          const SizedBox(height: 12),
          _buildTextField(contactC, "Phone / Contact", Icons.phone),
        ],
      ),
      confirm: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkSlate,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => ctrl.addVendor(nameC.text, contactC.text),
          child: const Text(
            "SAVE VENDOR",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}

// ==========================================
// 3. VENDOR DETAIL PAGE (TRANSACTIONS)
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
          children: [
            Text(vendor.name, style: AppTheme.title),
            Text("Ledger History", style: AppTheme.subTitle),
          ],
        ),
        backgroundColor: AppTheme.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.darkSlate),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.darkSlate),
            tooltip: "Download Statement",
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. DASHBOARD HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.white,
              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
            ),
            child: Column(
              children: [
                const Text(
                  "TOTAL OUTSTANDING BALANCE",
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final liveVendor = controller.vendors.firstWhere(
                    (e) => e.docId == vendor.docId,
                    orElse: () => vendor,
                  );
                  return Text(
                    NumberFormat.simpleCurrency(
                      name: '৳',
                      decimalDigits: 0,
                    ).format(liveVendor.totalDue),
                    style: TextStyle(
                      fontSize: 40,
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
          ),

          // 2. ACTION BUTTONS (POS Style)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: "ADD BILL",
                    subLabel: "(CREDIT)",
                    color: AppTheme.creditRed,
                    icon: Icons.receipt_long,
                    onTap: () => _showTransactionDialog(context, 'CREDIT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    label: "PAYMENT",
                    subLabel: "(DEBIT)",
                    color: AppTheme.debitGreen,
                    icon: Icons.payments,
                    onTap: () => _showTransactionDialog(context, 'DEBIT'),
                  ),
                ),
              ],
            ),
          ),

          // 3. TRANSACTION HISTORY LIST
          Expanded(
            child: Container(
              color: AppTheme.white,
              child: Obx(() {
                if (controller.currentTransactions.isEmpty) {
                  return const Center(
                    child: Text(
                      "No transaction history",
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(0),
                  separatorBuilder:
                      (c, i) =>
                          const Divider(height: 1, color: AppTheme.bgGrey),
                  itemCount: controller.currentTransactions.length,
                  itemBuilder: (ctx, i) {
                    final t = controller.currentTransactions[i];
                    final isCredit = t.type == 'CREDIT';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            isCredit
                                ? AppTheme.creditRed.withOpacity(0.1)
                                : AppTheme.debitGreen.withOpacity(0.1),
                        child: Icon(
                          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          color:
                              isCredit
                                  ? AppTheme.creditRed
                                  : AppTheme.debitGreen,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        isCredit
                            ? (t.shipmentName ?? "New Bill")
                            : "Payment Sent",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(t.date),
                              style: AppTheme.subTitle,
                            ),
                            if (!isCredit) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgGrey,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t.paymentMethod ?? "Cash",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${isCredit ? '+' : '-'} ${NumberFormat.compact().format(t.amount)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color:
                                  isCredit
                                      ? AppTheme.creditRed
                                      : AppTheme.debitGreen,
                            ),
                          ),
                          if (t.cartons != null)
                            Text(
                              "Ctns: ${t.cartons}",
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _showDetailPopup(context, t),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Action Button
  Widget _buildActionButton({
    required String label,
    required String subLabel,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // --- ADD TRANSACTION DIALOG ---
  void _showTransactionDialog(BuildContext context, String type) {
    final bool isCredit = type == 'CREDIT';
    final amountC = TextEditingController();
    final paymentMethodC = TextEditingController();
    final notesC = TextEditingController();
    final shipNameC = TextEditingController();
    final cartonsC = TextEditingController();
    final Rx<DateTime> date = DateTime.now().obs;
    final Rx<DateTime?> shipDate = Rxn<DateTime>();
    final Rx<DateTime?> rcvDate = Rxn<DateTime>();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isCredit
                                ? AppTheme.creditRed.withOpacity(0.1)
                                : AppTheme.debitGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCredit ? Icons.receipt : Icons.payment,
                        color:
                            isCredit ? AppTheme.creditRed : AppTheme.debitGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCredit ? "Record New Bill" : "Make Payment",
                      style: AppTheme.title,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount & Date
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        amountC,
                        "Amount (BDT)",
                        Icons.attach_money,
                        isNum: true,
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
                          () => InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Date",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            child: Text(
                              DateFormat('yyyy-MM-dd').format(date.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (!isCredit) ...[
                  const SizedBox(height: 12),
                  _field(
                    paymentMethodC,
                    "Payment Method (e.g. Cash, Bank)",
                    Icons.credit_card,
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 30),
                const Text(
                  "Optional Details",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _field(
                        shipNameC,
                        "Ref/Shipment Name",
                        Icons.description,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(cartonsC, "Cartons", Icons.grid_view),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(notesC, "Private Notes", Icons.note),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCredit ? AppTheme.creditRed : AppTheme.debitGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (amountC.text.isEmpty) return;
                      // FUTURE PROOF: Passed vendorName so Expense Controller works perfectly
                      controller.addTransaction(
                        vendorId: vendor.docId!,
                        vendorName: vendor.name,
                        type: type,
                        amount: double.tryParse(amountC.text) ?? 0,
                        date: date.value,
                        paymentMethod: !isCredit ? paymentMethodC.text : null,
                        shipmentName: shipNameC.text,
                        cartons: cartonsC.text,
                        shipmentDate: shipDate.value,
                        receiveDate: rcvDate.value,
                        notes: notesC.text,
                      );
                    },
                    child: Text(
                      isCredit ? "SAVE BILL" : "CONFIRM PAYMENT",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isNum = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  // --- DETAIL POPUP ---
  void _showDetailPopup(BuildContext context, VendorTransaction t) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.type == 'CREDIT' ? "Bill Details" : "Payment Details",
                style: AppTheme.title,
              ),
              const Divider(height: 30),
              _row("Amount", "৳${t.amount}", isBold: true),
              _row("Date", DateFormat('dd MMM yyyy').format(t.date)),
              if (t.paymentMethod != null) _row("Method", t.paymentMethod!),
              if (t.shipmentName != null && t.shipmentName!.isNotEmpty)
                _row("Shipment", t.shipmentName!),
              if (t.cartons != null && t.cartons!.isNotEmpty)
                _row("Cartons", t.cartons!),
              if (t.notes != null && t.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: AppTheme.bgGrey,
                  child: Text(
                    "Note: ${t.notes}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted)),
          Text(
            val,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. PDF GENERATION LOGIC
  // ==========================================
  Future<void> _generatePDF(BuildContext context) async {
    final pdf = pw.Document();

    // Get latest data from controller
    final list = controller.currentTransactions;
    // Calculate total on the fly for the report
    double calculatedDue = 0;

    // Sort chronological for PDF
    final sortedList = List<VendorTransaction>.from(list);
    sortedList.sort((a, b) => a.date.compareTo(b.date));

    // Theme Colors for PDF
    final pdfPrimary = PdfColor.fromInt(AppTheme.darkSlate.value);
    final pdfRed = PdfColor.fromInt(AppTheme.creditRed.value);
    final pdfGreen = PdfColor.fromInt(AppTheme.debitGreen.value);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "VENDOR LEDGER REPORT",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfPrimary,
                        ),
                      ),
                      pw.Text(
                        "Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        vendor.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        vendor.contact,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: pdfPrimary, thickness: 1),
              pw.SizedBox(height: 10),

              // Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Date
                  1: const pw.FlexColumnWidth(3), // Description
                  2: const pw.FlexColumnWidth(1.5), // Debit (Payment)
                  3: const pw.FlexColumnWidth(1.5), // Credit (Bill)
                  4: const pw.FlexColumnWidth(2), // Balance
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: pdfPrimary),
                    children: [
                      _pdfHeaderCell("Date"),
                      _pdfHeaderCell("Description / Notes"),
                      _pdfHeaderCell("Paid (-)", align: pw.TextAlign.right),
                      _pdfHeaderCell("Billed (+)", align: pw.TextAlign.right),
                      _pdfHeaderCell("Balance", align: pw.TextAlign.right),
                    ],
                  ),
                  // Data Rows
                  ...sortedList.map((t) {
                    final isCredit = t.type == 'CREDIT';
                    if (isCredit) {
                      calculatedDue += t.amount;
                    } else {
                      calculatedDue -= t.amount;
                    }

                    return pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                      ),
                      children: [
                        _pdfCell(DateFormat('yyyy-MM-dd').format(t.date)),
                        _pdfCell(
                          "${t.shipmentName ?? (isCredit ? 'Bill' : 'Payment')} ${t.notes != null ? '(${t.notes})' : ''}",
                        ),
                        _pdfCell(
                          !isCredit ? t.amount.toStringAsFixed(0) : "-",
                          align: pw.TextAlign.right,
                          color: pdfGreen,
                        ),
                        _pdfCell(
                          isCredit ? t.amount.toStringAsFixed(0) : "-",
                          align: pw.TextAlign.right,
                          color: pdfRed,
                        ),
                        _pdfCell(
                          calculatedDue.toStringAsFixed(0),
                          align: pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: pdfPrimary),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "CLOSING BALANCE:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          "BDT ${calculatedDue.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: pdfPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Footer
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  "Authorized Signature _______________________",
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'Ledger_${vendor.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _pdfHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _pdfCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: color ?? PdfColors.black,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }
}
