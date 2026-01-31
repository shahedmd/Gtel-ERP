// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:intl/intl.dart';

class CashDrawerView extends StatelessWidget {
  // Inject the controller
  final controller = Get.put(CashDrawerController());

  // Formatter for BDT/Regular numbers
  final NumberFormat currencyFormatter = NumberFormat('#,##0.00');

  CashDrawerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Slightly darker for better contrast
      appBar: AppBar(
        title: const Text(
          "ERP Cash Position",
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.blue.shade900,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${DateFormat('dd MMM yyyy').format(controller.selectedRange.value.start)} - ${DateFormat('dd MMM yyyy').format(controller.selectedRange.value.end)}",
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // A. GRAND TOTAL CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueGrey.shade900,
                              Colors.blueGrey.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "TOTAL LIQUID ASSETS",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "${currencyFormatter.format(controller.grandTotal.value)} ৳",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Monospace', // More financial look
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // B. High Level Overview (Mapped correctly to new controller vars)
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Sales Income",
                              controller.rawSalesTotal.value,
                              Colors.green[700]!,
                              Icons.arrow_upward,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Due Collect/Add",
                              controller.rawCollectionTotal.value,
                              Colors.blue[700]!,
                              Icons.add_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Total Expense",
                              controller.rawExpenseTotal.value,
                              Colors.red[700]!,
                              Icons.arrow_downward,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // C. Net Holdings Breakdown
                      _sectionHeader("ACCOUNTS OVERVIEW"),
                      _buildAssetTile(
                        "Direct Cash",
                        "Cash in Drawer",
                        controller.netCash.value,
                        Icons.payments_outlined,
                        Colors.teal,
                      ),
                      const SizedBox(height: 10),
                      _buildAssetTile(
                        "Bank Balance",
                        "All linked banks",
                        controller.netBank.value,
                        Icons.account_balance_outlined,
                        Colors.indigo,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAssetTile(
                              "Bkash",
                              "Mobile Banking",
                              controller.netBkash.value,
                              Icons.phone_android,
                              Colors.pink,
                              isSmall: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildAssetTile(
                              "Nagad",
                              "Mobile Banking",
                              controller.netNagad.value,
                              Icons.payment,
                              Colors.orange,
                              isSmall: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // D. Quick Actions
                      _sectionHeader("FUND MANAGEMENT"),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              "Manual Deposit",
                              Icons.add_circle_outline,
                              Colors.blue[800]!,
                              () => _showAddDialog(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionButton(
                              "Bank Withdraw",
                              Icons.move_down,
                              Colors.orange[800]!,
                              () => _showCashOutDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // E. Recent Transactions
                      _sectionHeader("TRANSACTION STATEMENT"),
                      controller.recentTransactions.isEmpty
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                "No transactions in this period",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.recentTransactions.length,
                            itemBuilder: (context, index) {
                              return _transactionTile(
                                controller.recentTransactions[index],
                              );
                            },
                          ),
                      const SizedBox(height: 30),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Row(
            children: [
              _chip("Today", DateFilter.daily),
              _chip("This Month", DateFilter.monthly),
              _chip("This Year", DateFilter.yearly),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text("Custom"),
                  selected: controller.filterType.value == DateFilter.custom,
                  onSelected: (selected) async {
                    if (selected) {
                      var res = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2022),
                        lastDate: DateTime.now(),
                        initialDateRange: controller.selectedRange.value,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blueGrey.shade900,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (res != null) controller.updateCustomDate(res);
                    }
                  },
                ),
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
        selectedColor: Colors.blueGrey.shade800,
        backgroundColor: Colors.grey.shade100,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black54,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _statCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10, // slightly smaller for longer text
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(amount),
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile(
    String title,
    String subtitle,
    double amount,
    IconData icon,
    Color color, {
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isSmall ? 18 : 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmall ? 13 : 15,
                    color: Colors.black87,
                  ),
                ),
                if (!isSmall)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          Text(
            "${currencyFormatter.format(amount)} ৳",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmall ? 14 : 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// **PROFESSIONAL TRANSACTION TILE**
  /// Displays Bank Name, Account Number, and clear financial formatting.
  Widget _transactionTile(DrawerTransaction tx) {
    // Determine colors
    bool isCredit = tx.type == 'sale' || tx.type == 'collection';
    Color amountColor = isCredit ? Colors.green[700]! : Colors.red[700]!;

    // Determine Icon
    IconData icon;
    if (tx.type == 'sale') {
      icon = Icons.shopping_bag_outlined;
    }  if (tx.type == 'collection') {
      icon = Icons.input;
    }
     if (tx.type == 'withdraw') {
       icon = Icons.output;
     } else {
       icon = Icons.receipt_long_outlined; // Expense
     }

    // Build Payment Method String (e.g. "BRAC BANK • 1234...")
    String methodInfo = tx.method.toUpperCase();
    if (tx.bankName != null && tx.bankName!.isNotEmpty) {
      methodInfo = tx.bankName!;
    }

    String subDetails = "";
    if (tx.accountDetails != null && tx.accountDetails!.isNotEmpty) {
      subDetails = tx.accountDetails!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: amountColor, size: 18),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tx.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${isCredit ? '+' : '-'}${currencyFormatter.format(tx.amount)}",
                      style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Bottom Row: Date & Method Details
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(tx.date),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Method Badge / Text
                    Expanded(
                      child: Text(
                        "$methodInfo ${subDetails.isNotEmpty ? '• $subDetails' : ''}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.blueGrey[400],
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
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
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        shadowColor: color.withOpacity(0.4),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: onTap,
    );
  }

  // =========================================================
  // DIALOGS (UPDATED FOR DETAILED INPUT)
  // =========================================================

  void _showAddDialog() {
    final amt = TextEditingController();
    final note = TextEditingController();
    // Bank Details Controllers
    final bankNameCtrl = TextEditingController();
    final accountNoCtrl = TextEditingController();

    String method = 'cash';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                bool showBankFields = [
                  'bank',
                  'bkash',
                  'nagad',
                ].contains(method);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Manual Deposit / Investment",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount Field
                    TextField(
                      controller: amt,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        prefixText: "৳ ",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Source / Description
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: "Source / Description",
                        hintText: "e.g. Loan from Owner",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Method Dropdown
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(
                        labelText: "Deposit To",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
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
                      onChanged: (v) {
                        setState(() {
                          method = v!;
                        });
                      },
                    ),

                    // CONDITIONAL BANK FIELDS
                    if (showBankFields) ...[
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: bankNameCtrl,
                              decoration: InputDecoration(
                                labelText:
                                    method == 'bank'
                                        ? "Bank Name"
                                        : "Provider Name",
                                hintText:
                                    method == 'bank'
                                        ? "e.g. BRAC Bank"
                                        : "e.g. Personal Bkash",
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                            const Divider(),
                            TextField(
                              controller: accountNoCtrl,
                              decoration: const InputDecoration(
                                labelText: "Account No / Transaction ID",
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          if (amt.text.isNotEmpty) {
                            controller.addManualCash(
                              amount: double.parse(amt.text),
                              method: method,
                              desc: note.text,
                              bankName:
                                  showBankFields ? bankNameCtrl.text : null,
                              accountNo:
                                  showBankFields ? accountNoCtrl.text : null,
                            );
                            Get.back();
                          }
                        },
                        child: const Text(
                          "Confirm Deposit",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCashOutDialog() {
    final amt = TextEditingController();
    final bankNameCtrl = TextEditingController();
    final accountNoCtrl = TextEditingController();
    String method = 'bank';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Withdraw from Assets",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Cash Out for personal use or transfer.",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),

                    // Dropdown
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
                      onChanged: (v) => setState(() => method = v!),
                      decoration: const InputDecoration(
                        labelText: "Withdraw From",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Bank Details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: bankNameCtrl,
                            decoration: InputDecoration(
                              labelText:
                                  method == 'bank' ? "Bank Name" : "Provider",
                              hintText: "Source Name",
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: accountNoCtrl,
                            decoration: const InputDecoration(
                              labelText: "Account No / Cheque No",
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Amount
                    TextField(
                      controller: amt,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount to Withdraw",
                        prefixText: "৳ ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          if (amt.text.isNotEmpty) {
                            controller.cashOutFromBank(
                              amount: double.parse(amt.text),
                              fromMethod: method,
                              bankName: bankNameCtrl.text,
                              accountNo: accountNoCtrl.text,
                            );
                          }
                        },
                        child: const Text(
                          "Process Withdraw",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
