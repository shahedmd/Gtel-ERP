// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
// Ensure this import points to your actual controller file location
import 'package:gtel_erp/Cash/controller.dart';
import 'package:intl/intl.dart';

class CashDrawerView extends StatelessWidget {
  // Use Get.put to instantiate the controller if not already present
  final controller = Get.put(CashDrawerController());
  final NumberFormat currencyFormatter = NumberFormat('#,##0.00');

  CashDrawerView({super.key});

  // --- THEME COLORS ---
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color bgLight = Color(0xFFF1F5F9);
  static const Color borderCol = Color(0xFFCBD5E1);
  static const Color accentBlue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Treasury & Cash Flow",
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkBlue),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 24),
            tooltip: "Download PDF Report",
            onPressed: () => controller.downloadPdf(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // 1. FILTER BAR
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A. GRAND TOTAL CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [darkBlue, darkBlue.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: darkBlue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "NET LIQUID ASSETS",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${currencyFormatter.format(controller.grandTotal.value)} ৳",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd MMM').format(
                                          controller.selectedRange.value.start,
                                        ) +
                                        (controller.filterType.value !=
                                                DateFilter.daily
                                            ? " - ${DateFormat('dd MMM').format(controller.selectedRange.value.end)}"
                                            : ""),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // B. SUMMARY ROW (Inflow/Outflow)
                      Row(
                        children: [
                          _summaryItem(
                            "Sales Income",
                            controller.rawSalesTotal.value,
                            Colors.green.shade700,
                            Icons.arrow_downward,
                          ),
                          const SizedBox(width: 12),
                          _summaryItem(
                            "Collections",
                            controller.rawCollectionTotal.value,
                            Colors.blue.shade700,
                            Icons.savings,
                          ),
                          const SizedBox(width: 12),
                          _summaryItem(
                            "Expenses/Out",
                            controller.rawExpenseTotal.value,
                            Colors.red.shade700,
                            Icons.arrow_upward,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // C. ASSETS GRID
                      const Text(
                        "ACCOUNTS BREAKDOWN",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 6, // Adjusted for better fit
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _assetCard(
                            "Cash in Hand",
                            controller.netCash.value,
                            Icons.payments_outlined,
                            Colors.teal,
                          ),
                          _assetCard(
                            "Bank Accounts",
                            controller.netBank.value,
                            Icons.account_balance_outlined,
                            Colors.indigo,
                          ),
                          _assetCard(
                            "Bkash Wallet",
                            controller.netBkash.value,
                            Icons.phone_android_outlined,
                            Colors.pink,
                          ),
                          _assetCard(
                            "Nagad Wallet",
                            controller.netNagad.value,
                            Icons.local_offer_outlined,
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // D. QUICK ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              "Manual Deposit",
                              Icons.add_circle_outline,
                              accentBlue,
                              () => _showAddDialog(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionBtn(
                              "Withdraw Funds",
                              Icons.remove_circle_outline,
                              Colors.orange.shade800,
                              () => _showCashOutDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // E. TRANSACTIONS LIST
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "RECENT ACTIVITY",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            "${controller.recentTransactions.length} entries",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderCol),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.recentTransactions.length,
                          separatorBuilder:
                              (c, i) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                          itemBuilder:
                              (context, index) => _transactionRow(
                                controller.recentTransactions[index],
                              ),
                        ),
                      ),
                      const SizedBox(height: 40),
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

  // =========================================
  // SUB-WIDGETS
  // =========================================

  Widget _summaryItem(String label, double val, Color col, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: col.withOpacity(0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.compact().format(val),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: col,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetCard(String title, double val, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: col.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: col, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "${currencyFormatter.format(val)} ৳",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
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

  Widget _transactionRow(DrawerTransaction tx) {
    bool isCredit = tx.type == 'sale' || tx.type == 'collection';
    bool isDebit = tx.type == 'expense' || tx.type == 'withdraw';

    Color amountColor = isCredit ? Colors.green.shade700 : Colors.red.shade700;
    IconData icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: amountColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM HH:mm').format(tx.date),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tx.method.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (tx.bankName != null || tx.accountDetails != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "${tx.bankName ?? ''} ${tx.accountDetails != null ? '(${tx.accountDetails})' : ''}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${isDebit ? '-' : '+'}${currencyFormatter.format(tx.amount)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color col,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: col,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white, // <--- Moved color inside decoration
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Row(
        children: [
          Expanded(child: _filterBtn("Today", DateFilter.daily)),
          const SizedBox(width: 8),
          Expanded(child: _filterBtn("Month", DateFilter.monthly)),
          const SizedBox(width: 8),
          Expanded(child: _filterBtn("Year", DateFilter.yearly)),
          const SizedBox(width: 8),

          // Custom Date Picker Icon
          InkWell(
            onTap: () async {
              var res = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2022),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: darkBlue,
                        onPrimary: Colors.white,
                        onSurface: darkBlue,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (res != null) controller.updateCustomDate(res);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: borderCol),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, DateFilter type) {
    return Obx(() {
      bool sel = controller.filterType.value == type;
      return InkWell(
        onTap: () => controller.setFilter(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? darkBlue : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: sel ? darkBlue : borderCol),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: sel ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      );
    });
  }

  // =========================================
  // DIALOGS
  // =========================================

  void _showAddDialog() {
    final amt = TextEditingController();
    final note = TextEditingController();
    final bankName = TextEditingController();
    final accNo = TextEditingController();
    String method = 'cash';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Manual Deposit / Collection",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: method,
                  dropdownColor: Colors.white,
                  items:
                      ['cash', 'bank', 'bkash', 'nagad']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => method = v!,
                  decoration: _inputDeco(
                    "Target Account",
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amt,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco("Amount (BDT)", Icons.attach_money),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: _inputDeco(
                    "Description / Note",
                    Icons.description,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankName,
                  decoration: _inputDeco(
                    "Bank/Provider (Optional)",
                    Icons.business,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accNo,
                  decoration: _inputDeco(
                    "Account/Ref No (Optional)",
                    Icons.numbers,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (amt.text.isNotEmpty) {
                        controller.addManualCash(
                          amount: double.parse(amt.text),
                          method: method,
                          desc:
                              note.text.isEmpty ? "Manual Deposit" : note.text,
                          bankName: bankName.text,
                          accountNo: accNo.text,
                        );
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "CONFIRM DEPOSIT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  void _showCashOutDialog() {
    final amt = TextEditingController();
    final bankName = TextEditingController();
    final accNo = TextEditingController();
    String method = 'bank'; // Default to bank for withdrawals usually

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Withdraw Funds",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: method,
                  dropdownColor: Colors.white,
                  items:
                      ['bank', 'bkash', 'nagad', 'cash']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => method = v!,
                  decoration: _inputDeco(
                    "Withdraw From",
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amt,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco("Amount (BDT)", Icons.attach_money),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankName,
                  decoration: _inputDeco("Bank/Provider Name", Icons.business),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accNo,
                  decoration: _inputDeco(
                    "Check/Ref Number",
                    Icons.confirmation_number,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (amt.text.isNotEmpty) {
                        controller.cashOutFromBank(
                          amount: double.parse(amt.text),
                          fromMethod: method,
                          bankName: bankName.text,
                          accountNo: accNo.text,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "CONFIRM WITHDRAWAL",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );
  }
}
