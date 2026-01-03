// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../Sales/controller.dart';
import 'model.dart';

class DailySalesPage extends StatelessWidget {
  final DailySalesController ctrl = Get.put(DailySalesController());

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

  // --- 1. HEADER (Title, Date, Search) ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
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
              Obx(
                () => Text(
                  "Audit for ${DateFormat('EEEE, dd MMMM yyyy').format(ctrl.selectedDate.value)}",
                  style: const TextStyle(fontSize: 14, color: textMuted),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search Bar
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
                prefixIcon: Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Date Selector
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
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text("Filter Date"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Export Button
          ElevatedButton.icon(
            onPressed: () => ctrl.generateProfessionalPDF(),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              color: Colors.white,
              size: 16,
            ),
            label: const Text(
              "Export Statement",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
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
                "Total Collected",
                ctrl.paidAmount.value,
                FontAwesomeIcons.handHoldingDollar,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _metricCard(
                "Outstanding Debt",
                ctrl.debtorPending.value,
                FontAwesomeIcons.circleExclamation,
                Colors.redAccent,
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
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: FaIcon(icon, size: 16, color: color)),
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
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "৳ ${value.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
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
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            child: FaIcon(
              FontAwesomeIcons.receipt,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TOTAL ORDERS",
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
                  fontSize: 20,
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

  // --- 3. THE DATA TABLE ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
              "Payment Method",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ), // Increased flex
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
          SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final filtered = _getFilteredList();
    if (filtered.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final sale = filtered[index];
        return _buildSaleRow(context, sale);
      },
    );
  }

  Widget _buildSaleRow(BuildContext context, SaleModel sale) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: InkWell(
        onTap: () {
          if (sale.pending > 0) _showPaymentDialog(context, sale);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Customer Name & Invoice ID
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
                      ),
                    ),
                    Text(
                      "Inv: ${sale.transactionId ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 11,
                        color: activeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(sale.timestamp),
                      style: const TextStyle(fontSize: 10, color: textMuted),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Expanded(flex: 2, child: _statusBadge(sale)),
              // Payment Method (Now shows Multi nicely)
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
              // Amount
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
              // Pending
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
              // Action
              SizedBox(
                width: 60,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.black26,
                  ),
                  onPressed: () => _confirmDelete(sale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, SaleModel sale) {
    final amountC = TextEditingController(text: sale.pending.toString());
    final RxString method = "cash".obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Collect Payment",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Customer: ${sale.name}",
                style: const TextStyle(color: textMuted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount to Pay",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => DropdownButtonFormField<String>(
                  value: method.value,
                  decoration: const InputDecoration(
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ctrl.applyDebtorPayment(
                          sale.name,
                          double.parse(amountC.text),
                          {"type": method.value},
                          date: DateTime.now(),
                        );
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeAccent,
                      ),
                      child: const Text(
                        "Record Payment",
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

  void _confirmDelete(SaleModel sale) {
    Get.defaultDialog(
      title: "Delete Transaction?",
      middleText: "Remove entry for ${sale.name}?",
      textConfirm: "Delete",
      buttonColor: Colors.redAccent,
      confirmTextColor: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              isPaid
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isPaid ? "PAID" : "PARTIAL / DUE",
          style: TextStyle(
            color: isPaid ? Colors.green : Colors.orange,
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
    return ctrl.salesList
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              (s.transactionId ?? '').toLowerCase().contains(
                q,
              ) || // Added Invoice Search
              s.customerType.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.folderOpen, size: 50, color: Colors.black12),
          SizedBox(height: 16),
          Text("No sales records found", style: TextStyle(color: textMuted)),
        ],
      ),
    );
  }
}
