// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'controller.dart'; // Ensure this points to your file
import 'model.dart'; // Ensure this points to your file

class DailySalesPage extends StatelessWidget {
  // Dependency Injection
  final DailySalesController ctrl = Get.put(DailySalesController());

  // Theme Constants
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  DailySalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Obx(() {
        // Loading State (Only if list is empty to prevent flicker)
        if (ctrl.isLoading.value && ctrl.salesList.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: activeAccent),
          );
        }

        return Column(
          children: [
            _buildHeader(context),
            _buildMetricsRow(),
            _buildTableHead(),
            Expanded(child: _buildMainContent(context)),
          ],
        );
      }),
    );
  }

  // ==========================================================
  // 1. HEADER SECTION
  // ==========================================================
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daily Sales Ledger",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  "Audit for ${DateFormat('EEEE, dd MMMM yyyy').format(ctrl.selectedDate.value)}",
                  style: const TextStyle(fontSize: 14, color: textMuted),
                ),
              ),
            ],
          ),
          const Spacer(),
          // --- Search Bar ---
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: bgGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              onChanged: (v) => ctrl.filterQuery.value = v,
              decoration: const InputDecoration(
                hintText: "Search Name / Invoice ID...",
                prefixIcon: Icon(Icons.search, size: 20, color: textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // --- Date Filter ---
          OutlinedButton.icon(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: ctrl.selectedDate.value,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (p != null) ctrl.changeDate(p);
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text("Filter Date"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // --- Export PDF ---
          ElevatedButton.icon(
            onPressed: () => ctrl.generateProfessionalPDF(),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              color: Colors.white,
              size: 16,
            ),
            label: const Text(
              "Export Report",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 2. METRICS ROW
  // ==========================================================
  Widget _buildMetricsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _metricCard(
                "Gross Sales",
                ctrl.totalSales.value,
                FontAwesomeIcons.chartLine,
                activeAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _metricCard(
                "Cash Collected",
                ctrl.paidAmount.value,
                FontAwesomeIcons.handHoldingDollar,
                Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _metricCard(
                "Outstanding Due",
                ctrl.debtorPending.value,
                FontAwesomeIcons.fileInvoiceDollar,
                Colors.orange.shade800,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _orderCountCard()),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: FaIcon(icon, size: 20, color: color)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "৳ ${value.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                      fontFamily: 'RobotoMono', // Optional monospace look
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkSlate.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white10,
            child: FaIcon(
              FontAwesomeIcons.receipt,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TOTAL TRANSACTIONS",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${ctrl.salesList.length}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 3. TABLE STRUCTURE
  // ==========================================================
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "Customer / Bill To",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Status",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Payment Info",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Total Bill",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Balance Due",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 100), // Actions Space
        ],
      ),
    );
  }

  // ==========================================================
  // 4. MAIN CONTENT & LIST
  // ==========================================================
  Widget _buildMainContent(BuildContext context) {
    final filtered = _getFilteredList();
    if (filtered.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final sale = filtered[index];
        return _buildSaleRow(context, sale);
      },
    );
  }

  Widget _buildSaleRow(BuildContext context, SaleModel sale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: InkWell(
        onTap: () {
          // Quick Action: If pending > 0, open payment dialog
          if (sale.pending > 0) _showPaymentDialog(context, sale);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Customer & Invoice
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sale.transactionId ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 10,
                              color: textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('hh:mm a').format(sale.timestamp),
                          style: const TextStyle(
                            fontSize: 10,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Expanded(flex: 2, child: _statusBadge(sale)),

              // Payment Method
              Expanded(
                flex: 3,
                child: Text(
                  ctrl.formatPaymentMethod(sale.paymentMethod),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Total Amount
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${sale.amount.toStringAsFixed(2)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                  ),
                ),
              ),

              // Pending / Due
              Expanded(
                flex: 2,
                child: Text(
                  sale.pending > 0
                      ? "৳ ${sale.pending.toStringAsFixed(2)}"
                      : "CLEARED",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sale.pending > 0 ? Colors.redAccent : Colors.green,
                  ),
                ),
              ),

              // Actions
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // PRINT
                    if (sale.transactionId != null)
                      IconButton(
                        tooltip: "Reprint Invoice",
                        icon: const Icon(
                          Icons.print_outlined,
                          size: 20,
                          color: Colors.blueGrey,
                        ),
                        onPressed:
                            () => ctrl.reprintInvoice(sale.transactionId!),
                      ),
                    // DELETE
                    IconButton(
                      tooltip: "Delete Daily Entry",
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _confirmDelete(sale),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // 5. DIALOGS & HELPERS
  // ==========================================================

  // Updated: Includes Reference/Trx ID field to match future-proof controller
  void _showPaymentDialog(BuildContext context, SaleModel sale) {
    final amountC = TextEditingController(text: sale.pending.toString());
    final refC = TextEditingController(); // New Reference Field
    final RxString method = "cash".obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Collect Due Payment",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Customer: ${sale.name}",
                style: const TextStyle(color: textMuted),
              ),
              const SizedBox(height: 24),

              // Amount Field
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount Received",
                  border: OutlineInputBorder(),
                  prefixText: "৳ ",
                ),
              ),
              const SizedBox(height: 16),

              // Method Dropdown
              Obx(
                () => DropdownButtonFormField<String>(
                  value: method.value,
                  decoration: const InputDecoration(
                    labelText: "Payment Method",
                    border: OutlineInputBorder(),
                  ),
                  items:
                      ["cash", "bkash", "nagad", "bank"]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => method.value = v!,
                ),
              ),
              const SizedBox(height: 16),

              // Reference / Trx ID (Future Proofing)
              TextField(
                controller: refC,
                decoration: const InputDecoration(
                  labelText: "Transaction Ref / Note (Optional)",
                  hintText: "e.g. Bkash Trx ID...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final double amt = double.tryParse(amountC.text) ?? 0.0;
                        if (amt <= 0) return;

                        // Call controller with transactionId (ref)
                        await ctrl.applyDebtorPayment(
                          sale.name,
                          amt,
                          {"type": method.value}, // Basic type
                          date: DateTime.now(),
                          transactionId:
                              refC.text.isEmpty ? null : refC.text, // Pass Ref
                        );
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "Confirm Payment",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Updated Text to reflect safe delete
  void _confirmDelete(SaleModel sale) {
    Get.defaultDialog(
      title: "Delete Daily Entry?",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText:
          "This will remove the transaction from the Daily Ledger only.\n\nThe Master Invoice will remain but be marked as 'Entry Removed'.",
      textConfirm: "Delete Entry",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        ctrl.deleteSale(sale.id);
        Get.back();
      },
    );
  }

  Widget _statusBadge(SaleModel sale) {
    bool isPaid = sale.pending <= 0;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              isPaid
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color:
                isPaid
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
          ),
        ),
        child: Text(
          isPaid ? "PAID" : "DUE",
          style: TextStyle(
            color: isPaid ? Colors.green.shade700 : Colors.orange.shade800,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<SaleModel> _getFilteredList() {
    final q = ctrl.filterQuery.value.toLowerCase();
    if (q.isEmpty) return ctrl.salesList;
    return ctrl.salesList.where((s) {
      final name = s.name.toLowerCase();
      final id = (s.transactionId ?? '').toLowerCase();
      final type = s.customerType.toLowerCase();
      return name.contains(q) || id.contains(q) || type.contains(q);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(FontAwesomeIcons.folderOpen, size: 48, color: Colors.black12),
          SizedBox(height: 16),
          Text(
            "No sales records found",
            style: TextStyle(color: textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
