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

              // Calculate Total Pages
              int totalPages =
                  (controller.totalItems.value / controller.itemsPerPage)
                      .ceil();
              if (totalPages == 0) totalPages = 1;

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

                      // B. SUMMARY ROW
                      Row(
                        children: [
                          _summaryItem(
                            "Total Income",
                            controller.rawSalesTotal.value +
                                controller.rawCollectionTotal.value,
                            Colors.green.shade700,
                            Icons.arrow_downward,
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
                        childAspectRatio: 6,
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

                      // D. QUICK ACTIONS (Updated for 3 actions)
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              "Deposit",
                              Icons.add_circle_outline,
                              Colors.teal.shade600,
                              () => _showAddDialog(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionBtn(
                              "Withdraw",
                              Icons.remove_circle_outline,
                              Colors.red.shade600,
                              () => _showWithdrawDialog(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionBtn(
                              "Transfer",
                              Icons.swap_horiz_outlined,
                              Colors.orange.shade800,
                              () => _showTransferDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // E. TRANSACTION HEADER
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
                            "Total: ${controller.totalItems.value}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // F. TRANSACTIONS LIST
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          children: [
                            if (controller.paginatedTransactions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(30.0),
                                child: Text(
                                  "No transactions found in this period.",
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount:
                                    controller.paginatedTransactions.length,
                                separatorBuilder:
                                    (c, i) => Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                itemBuilder:
                                    (context, index) => _transactionRow(
                                      controller.paginatedTransactions[index],
                                    ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // G. PAGINATION CONTROLS
                      if (controller.totalItems.value > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _pageBtn(
                                icon: Icons.chevron_left,
                                onTap:
                                    controller.currentPage.value > 1
                                        ? () => controller.previousPage()
                                        : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  "Page ${controller.currentPage.value} of $totalPages",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              _pageBtn(
                                icon: Icons.chevron_right,
                                onTap:
                                    controller.currentPage.value < totalPages
                                        ? () => controller.nextPage()
                                        : null,
                              ),
                            ],
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

  Widget _pageBtn({required IconData icon, VoidCallback? onTap}) {
    bool disabled = onTap == null;
    return Container(
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: disabled ? Colors.transparent : borderCol),
      ),
      child: IconButton(
        icon: Icon(icon, color: disabled ? Colors.grey : darkBlue),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormatter.format(val),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: col,
                ),
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
    bool isTransfer = tx.type == 'transfer';

    Color amountColor;
    IconData icon;
    Color bgCol;

    if (isTransfer) {
      amountColor = Colors.orange.shade800;
      icon = Icons.swap_horiz;
      bgCol = Colors.orange;
    } else if (isCredit) {
      amountColor = Colors.green.shade700;
      icon = Icons.arrow_downward;
      bgCol = Colors.green;
    } else {
      amountColor = Colors.red.shade700;
      icon = Icons.arrow_upward;
      bgCol = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgCol.withOpacity(0.1),
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
              "${isTransfer ? '' : (isDebit ? '-' : '+')}${currencyFormatter.format(tx.amount)}",
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

  // Re-designed action button to fit 3 items horizontally nicely
  Widget _actionBtn(
    String label,
    IconData icon,
    Color col,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: col,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
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
                    color: Colors.teal,
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
                      backgroundColor: Colors.teal.shade600,
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

  // --- NEW: WITHDRAW / CASHOUT DIALOG ---
  void _showWithdrawDialog(BuildContext context) {
    final amt = TextEditingController();
    final note = TextEditingController();
    final bankName = TextEditingController();
    final accNo = TextEditingController();
    String method = 'Bank';
    DateTime selectedDate = DateTime.now();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Withdraw / Cashout",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date Picker
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Method Selector
                    DropdownButtonFormField<String>(
                      value: method,
                      dropdownColor: Colors.white,
                      items:
                          ['Cash', 'Bank', 'Bkash', 'Nagad']
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => method = v!),
                      decoration: _inputDeco(
                        "Withdraw From",
                        Icons.account_balance_wallet,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextField(
                      controller: amt,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(
                        "Amount (BDT)",
                        Icons.attach_money,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note
                    TextField(
                      controller: note,
                      decoration: _inputDeco(
                        "Description / Note",
                        Icons.description,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Extra Details if not Cash
                    if (method != 'Cash') ...[
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
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (amt.text.isEmpty || note.text.isEmpty) {
                            Get.snackbar(
                              "Required",
                              "Amount and Note are required!",
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                            return;
                          }
                          controller.withdrawFund(
                            amount: double.parse(amt.text),
                            method: method,
                            desc: note.text,
                            date: selectedDate,
                            bankName: bankName.text,
                            accountNo: accNo.text,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "CONFIRM WITHDRAW",
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
            );
          },
        ),
      ),
    );
  }

  void _showTransferDialog() {
    final amt = TextEditingController();
    final bankName = TextEditingController();
    final accNo = TextEditingController();
    final note = TextEditingController();

    // Default selections
    String fromMethod = 'bank';
    String toMethod = 'cash';
    final RxString fromVal = fromMethod.obs;
    final RxString toVal = toMethod.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: SingleChildScrollView(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Fund Transfer",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Move funds between accounts",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),

                  // FROM -> TO ROW
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "From",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: fromVal.value,
                              dropdownColor: Colors.white,
                              isExpanded: true,
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
                                fromVal.value = v!;
                                // Prevent selecting same value
                                if (toVal.value == v) {
                                  toVal.value = (v == 'cash') ? 'bank' : 'cash';
                                }
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 20,
                        ),
                        child: Icon(Icons.arrow_forward, color: Colors.grey),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "To",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: toVal.value,
                              dropdownColor: Colors.white,
                              isExpanded: true,
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
                                toVal.value = v!;
                                if (fromVal.value == v) {
                                  fromVal.value =
                                      (v == 'cash') ? 'bank' : 'cash';
                                }
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: amt,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco("Amount (BDT)", Icons.attach_money),
                  ),
                  const SizedBox(height: 12),

                  // Details Section (Visible if Bank/Bkash/Nagad involved)
                  if (fromVal.value != 'cash' || toVal.value != 'cash') ...[
                    TextField(
                      controller: bankName,
                      decoration: _inputDeco(
                        "Bank/Provider Name",
                        Icons.business,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accNo,
                      decoration: _inputDeco("Account/Check No", Icons.numbers),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: note,
                    decoration: _inputDeco("Note (Optional)", Icons.note),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (amt.text.isNotEmpty &&
                            double.tryParse(amt.text) != null) {
                          controller.transferFund(
                            amount: double.parse(amt.text),
                            fromMethod: _capitalize(fromVal.value),
                            toMethod: _capitalize(toVal.value),
                            bankName: bankName.text,
                            accountNo: accNo.text,
                            description:
                                note.text.isNotEmpty
                                    ? note.text
                                    : "Transfer: ${_capitalize(fromVal.value)} to ${_capitalize(toVal.value)}",
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "CONFIRM TRANSFER",
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
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

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