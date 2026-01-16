// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'controller.dart';
import 'model.dart';

class DailySalesPage extends StatelessWidget {
  // Dependency Injection
  final DailySalesController ctrl = Get.put(DailySalesController());

  // Modern Color Palette (Material 3 / Slate Style)
  static const Color bgSlate = Color(0xFFF1F5F9);
  static const Color darkText = Color(0xFF0F172A);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color alertRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFEA580C);

  DailySalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSlate,
      body: Obx(() {
        // Loading State
        if (ctrl.isLoading.value && ctrl.salesList.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: primaryBlue),
          );
        }

        return Column(
          children: [
            _buildHeader(context),
            _buildMetricsGrid(),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const FaIcon(
              FontAwesomeIcons.cashRegister,
              color: primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daily Sales Ledger",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  "Viewing Data for: ${DateFormat('EEEE, dd MMMM yyyy').format(ctrl.selectedDate.value)}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),

          // --- Search Bar ---
          Container(
            width: 250,
            height: 45,
            decoration: BoxDecoration(
              color: bgSlate,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: (v) => ctrl.filterQuery.value = v,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: "Search Invoice or Name...",
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // --- REFRESH BUTTON (NEW) ---
          IconButton(
            onPressed: () => ctrl.loadDailySales(),
            icon: const Icon(Icons.refresh, color: primaryBlue),
            tooltip: "Refresh Data",
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // --- Date Filter ---
          OutlinedButton.icon(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: ctrl.selectedDate.value,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: primaryBlue,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (p != null) ctrl.changeDate(p);
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text("Select Date"),
            style: OutlinedButton.styleFrom(
              foregroundColor: darkText,
              side: BorderSide(color: Colors.grey.shade300),
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
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text("Export Report"),
            style: ElevatedButton.styleFrom(
              backgroundColor: alertRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              elevation: 2,
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
  Widget _buildMetricsGrid() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: _metricCard(
              "Total Sales",
              ctrl.totalSales.value,
              FontAwesomeIcons.chartLine,
              primaryBlue,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _metricCard(
              "Cash Collected",
              ctrl.paidAmount.value,
              FontAwesomeIcons.handHoldingDollar,
              successGreen,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _metricCard(
              "Debtor Pending",
              ctrl.debtorPending.value,
              FontAwesomeIcons.fileInvoiceDollar,
              warningOrange,
            ),
          ),
          const SizedBox(width: 20),
          // Transaction Count Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: darkText,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: darkText.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.list,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TRANSACTIONS",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${ctrl.salesList.length}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "৳ ${value.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 3. TABLE HEADER
  // ==========================================================
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: darkText,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "CUSTOMER / INVOICE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "TYPE & STATUS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "PAYMENT METHOD",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "TOTAL AMOUNT",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "BALANCE DUE",
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 100), // Action button space
        ],
      ),
    );
  }

  // ==========================================================
  // 4. MAIN SALES LIST
  // ==========================================================
  Widget _buildMainContent(BuildContext context) {
    // Controller logic is already filtering the sales list
    final filtered = ctrl.filteredList;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No transactions found for this date",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
        itemBuilder: (context, index) {
          final sale = filtered[index];
          return _buildSaleRow(context, sale);
        },
      ),
    );
  }

  Widget _buildSaleRow(BuildContext context, SaleModel sale) {
    bool isDebtor = sale.customerType.toLowerCase().contains("debtor");

    return InkWell(
      onTap: () {
        // Only allow extra payment on Debtors who have Pending amount
        if (sale.pending > 0 && isDebtor) _showPaymentDialog(context, sale);
      },
      hoverColor: Colors.blue.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // 1. Customer Info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bgSlate,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sale.transactionId ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('hh:mm a').format(sale.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Type & Status
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDebtor
                              ? Colors.purple.shade50
                              : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            isDebtor
                                ? Colors.purple.shade100
                                : Colors.blue.shade100,
                      ),
                    ),
                    child: Text(
                      isDebtor ? "DEBTOR" : "RETAILER",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDebtor ? Colors.purple : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Payment Status
                  Text(
                    sale.pending > 0 ? "PARTIAL / DUE" : "FULLY PAID",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: sale.pending > 0 ? warningOrange : successGreen,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Payment Method
            Expanded(
              flex: 2,
              child: Text(
                ctrl.formatPaymentMethod(sale.paymentMethod),
                maxLines: 2, // Allow multiline for details
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),

            // 4. Amount
            Expanded(
              flex: 2,
              child: Text(
                "৳ ${sale.amount.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
            ),

            // 5. Balance Due
            Expanded(
              flex: 2,
              child: Text(
                sale.pending > 0 ? "৳ ${sale.pending.toStringAsFixed(2)}" : "-",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sale.pending > 0 ? alertRed : Colors.grey.shade300,
                ),
              ),
            ),

            // 6. Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.print_outlined,
                      size: 20,
                      color: Colors.blueGrey,
                    ),
                    tooltip: "Reprint Invoice",
                    onPressed:
                        () => ctrl.reprintInvoice(sale.transactionId ?? ""),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: isDebtor ? Colors.grey.shade300 : alertRed,
                    ),
                    tooltip:
                        isDebtor
                            ? "Manage in Ledger"
                            : "Delete & Restore Stock",
                    onPressed: () {
                      if (isDebtor) {
                        Get.snackbar(
                          "Restricted",
                          "Debtor sales must be managed in the Debtor Ledger.",
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                      } else {
                        _confirmDelete(sale);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 5. DIALOGS & UTILS
  // ==========================================================

  /// Shows dialog to collect due payment with details (Number/Bank)
  void _showPaymentDialog(BuildContext context, SaleModel sale) {
    final amountC = TextEditingController(text: sale.pending.toString());
    final detailsC = TextEditingController(); // For Number or Bank Name
    final RxString method = "cash".obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Collect Due Payment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgSlate,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Customer: ${sale.name}",
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      "Due: ৳${sale.pending}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: alertRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Inputs
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount Received",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixText: "৳ ",
                ),
              ),
              const SizedBox(height: 16),

              // Method Selection
              Obx(
                () => DropdownButtonFormField<String>(
                  value: method.value,
                  decoration: InputDecoration(
                    labelText: "Payment Method",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

              // Dynamic Detail Input based on Method
              Obx(() {
                if (method.value == 'cash') return const SizedBox.shrink();

                String label = "Details";
                IconData icon = Icons.info;

                if (method.value == 'bkash' || method.value == 'nagad') {
                  label = "${method.value.toUpperCase()} Number";
                  icon = Icons.phone_android;
                } else if (method.value == 'bank') {
                  label = "Bank Name & Account No";
                  icon = Icons.account_balance;
                }

                return TextField(
                  controller: detailsC,
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: Icon(icon, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Buttons
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

                        // Construct Payment Method Map
                        Map<String, dynamic> payMethodMap = {
                          "type": method.value,
                        };

                        if (method.value == 'bkash' ||
                            method.value == 'nagad') {
                          payMethodMap['number'] = detailsC.text;
                        } else if (method.value == 'bank') {
                          payMethodMap['bankName'] = detailsC.text;
                        }

                        await ctrl.applyDebtorPayment(
                          sale.name,
                          amt,
                          payMethodMap,
                          date: DateTime.now(),
                          transactionId: null, // Optional Ref
                        );
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
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

  void _confirmDelete(SaleModel sale) {
    Get.defaultDialog(
      title: "Delete Sale?",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: alertRed),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: const [
            Text(
              "This action is irreversible.",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "1. Daily Sales entry will be removed.\n2. Sales Invoice will be deleted.\n3. Customer History will be updated.\n4. STOCK WILL BE RESTORED.",
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
      textConfirm: "Confirm Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: alertRed,
      cancelTextColor: Colors.black87,
      onConfirm: () {
        ctrl.deleteSale(sale.id);
        Get.back();
      },
    );
  }
}
