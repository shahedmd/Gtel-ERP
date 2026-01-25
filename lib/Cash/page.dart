// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart'; // Ensure this matches your project structure
import 'package:intl/intl.dart';

class CashDrawerView extends StatelessWidget {
  // Inject the controller
  final controller = Get.put(CashDrawerController());

  // Formatter for BDT/Regular numbers (e.g. 1,500,000.00)
  final NumberFormat currencyFormatter = NumberFormat('#,##0.00');

  CashDrawerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "ERP Cash Drawer",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: "Download PDF Report",
            onPressed: () => controller.downloadPdf(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. TOP FILTER BAR
          _buildFilterBar(context),

          // 2. MAIN CONTENT
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return RefreshIndicator(
                onRefresh: () async => controller.fetchData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date Context Indicator
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          "Showing data for: ${DateFormat('dd MMM yyyy').format(controller.selectedRange.value.start)} - ${DateFormat('dd MMM yyyy').format(controller.selectedRange.value.end)}",
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      // A. GRAND TOTAL (ALL TOGETHER)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade700,
                              Colors.teal.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "TOTAL NET CASH (All Accounts)",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "${currencyFormatter.format(controller.grandTotal.value)} ৳",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // B. High Level Overview (Income vs Expense)
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Total Sales",
                              controller.rawSalesTotal.value,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statCard(
                              "Expenses",
                              controller.rawExpenseTotal.value,
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statCard(
                              "Added Cash",
                              controller.rawManualAddTotal.value,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // C. Net Holdings (Breakdown)
                      _sectionHeader("CURRENT CASH BREAKDOWN"),
                      _buildAssetTile(
                        "Direct Cash",
                        controller.netCash.value,
                        Icons.money,
                        Colors.teal,
                      ),
                      const SizedBox(height: 8),
                      _buildAssetTile(
                        "Bank Account",
                        controller.netBank.value,
                        Icons.account_balance,
                        Colors.indigo,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAssetTile(
                              "Bkash",
                              controller.netBkash.value,
                              Icons.phone_android,
                              Colors.pink,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildAssetTile(
                              "Nagad",
                              controller.netNagad.value,
                              Icons.payment,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // D. Quick Actions
                      _sectionHeader("MANAGE FUNDS"),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              "Add / Invest",
                              Icons.add_circle_outline,
                              Colors.blue[800]!,
                              () => _showAddDialog(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButton(
                              "Cash Out",
                              Icons.move_down,
                              Colors.orange[800]!,
                              () => _showCashOutDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // E. Recent Transactions
                      _sectionHeader("RECENT TRANSACTIONS"),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.recentTransactions.length,
                        itemBuilder: (context, index) {
                          return _transactionTile(
                            controller.recentTransactions[index],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // UI COMPONENTS & WIDGETS
  // =========================================================

  Widget _buildFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Row(
            children: [
              _chip("Today", DateFilter.daily),
              _chip("This Month", DateFilter.monthly),
              _chip("This Year", DateFilter.yearly),
              ActionChip(
                label: const Text("Custom"),
                backgroundColor:
                    controller.filterType.value == DateFilter.custom
                        ? Colors.blue[100]
                        : Colors.grey[200],
                onPressed: () async {
                  var res = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                    initialDateRange: controller.selectedRange.value,
                  );
                  if (res != null) controller.updateCustomDate(res);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, DateFilter type) {
    bool selected = controller.filterType.value == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (v) => controller.setFilter(type),
        selectedColor: Colors.blue[100],
        labelStyle: TextStyle(
          color: selected ? Colors.blue[900] : Colors.black,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _statCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          // Updated to use full format instead of compact
          Text(
            currencyFormatter.format(amount),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 14, // Slightly smaller to fit big numbers
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Text(
            "${currencyFormatter.format(amount)} ৳",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(DrawerTransaction tx) {
    bool isExp = tx.type == 'expense';
    bool isWith = tx.type == 'withdraw';
    Color c = isExp || isWith ? Colors.red[700]! : Colors.green[700]!;

    IconData icon;
    if (tx.type == 'sale') {
      icon = Icons.shopping_bag_outlined;
    } else if (tx.type == 'expense') {
      icon = Icons.receipt_long;
    } else if (tx.type == 'withdraw') {
      icon = Icons.arrow_circle_down;
    } else {
      icon = Icons.arrow_circle_up;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.withOpacity(0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "${DateFormat('dd MMM').format(tx.date)} • ${tx.type.toUpperCase()}",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            "${isExp ? '-' : '+'}${currencyFormatter.format(tx.amount)}",
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 1,
      ),
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onTap,
    );
  }

  // =========================================================
  // DIALOGS
  // =========================================================

  void _showAddDialog() {
    final amt = TextEditingController();
    final note = TextEditingController();
    String method = 'cash';
    Get.defaultDialog(
      title: "Add Income / Fund",
      content: Column(
        children: [
          TextField(
            controller: amt,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: note,
            decoration: const InputDecoration(
              labelText: "Source / Description",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(
              labelText: "Add To",
              border: OutlineInputBorder(),
            ),
            items:
                ['cash', 'bank', 'bkash', 'nagad']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toUpperCase()),
                      ),
                    )
                    .toList(),
            onChanged: (v) => method = v!,
          ),
        ],
      ),
      textConfirm: "Add Funds",
      confirmTextColor: Colors.white,
      onConfirm: () {
        if (amt.text.isNotEmpty) {
          controller.addManualCash(
            amount: double.parse(amt.text),
            method: method,
            desc: note.text,
          );
          Get.back();
        }
      },
    );
  }

  void _showCashOutDialog() {
    final amt = TextEditingController();
    String method = 'bank';
    Get.defaultDialog(
      title: "Withdraw to Cash",
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange[50],
            child: const Text(
              "This moves money from your Bank/Digital accounts into your Direct Cash drawer.",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: method,
            items:
                ['bank', 'bkash', 'nagad']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toUpperCase()),
                      ),
                    )
                    .toList(),
            onChanged: (v) => method = v!,
            decoration: const InputDecoration(
              labelText: "Withdraw From",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amt,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      textConfirm: "Process Withdraw",
      confirmTextColor: Colors.white,
      buttonColor: Colors.orange[800],
      onConfirm: () {
        if (amt.text.isNotEmpty) {
          controller.cashOutFromBank(
            amount: double.parse(amt.text),
            fromMethod: method,
          );
        }
      },
    );
  }
}
