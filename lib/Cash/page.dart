// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:intl/intl.dart';

class CashDrawerView extends StatelessWidget {
  final controller = Get.put(CashDrawerController());
  final NumberFormat currencyFormatter = NumberFormat('#,##0.00');

  CashDrawerView({super.key});

  static const Color darkBlue = Color(0xFF1E293B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderCol = Color(0xFFE2E8F0);

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
            fontSize: 16,
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
            icon: const Icon(Icons.print_outlined, size: 20),
            onPressed: () => controller.downloadPdf(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                onRefresh: () async => controller.fetchData(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: darkBlue,
                          borderRadius: BorderRadius.circular(8),
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
                                    color: Colors.white54,
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${currencyFormatter.format(controller.grandTotal.value)} ৳",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('dd MMM').format(
                                      controller.selectedRange.value.start,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // B. SUMMARY ROW
                      Row(
                        children: [
                          _summaryItem(
                            "Invoiced Sales",
                            controller.rawSalesTotal.value,
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _summaryItem(
                            "Collections",
                            controller.rawCollectionTotal.value,
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _summaryItem(
                            "Expenses",
                            controller.rawExpenseTotal.value,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // C. ASSETS GRID
                      const Text(
                        "ACCOUNTS BREAKDOWN",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _assetCard(
                            "Direct Cash",
                            controller.netCash.value,
                            Icons.payments,
                            Colors.teal,
                          ),
                          _assetCard(
                            "Bank",
                            controller.netBank.value,
                            Icons.account_balance,
                            Colors.indigo,
                          ),
                          _assetCard(
                            "Bkash",
                            controller.netBkash.value,
                            Icons.phone_android,
                            Colors.pink,
                          ),
                          _assetCard(
                            "Nagad",
                            controller.netNagad.value,
                            Icons.local_offer,
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // D. ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              "Add Funds",
                              Icons.add,
                              Colors.blue[800]!,
                              () => _showAddDialog(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionBtn(
                              "Withdraw",
                              Icons.remove,
                              Colors.orange[800]!,
                              () => _showCashOutDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // E. TRANSACTIONS
                      const Text(
                        "RECENT ACTIVITY",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.recentTransactions.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder:
                            (context, index) => _transactionRow(
                              controller.recentTransactions[index],
                            ),
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

  // --- WIDGETS ---

  Widget _summaryItem(String label, double val, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.compact().format(val),
              style: TextStyle(
                fontSize: 14,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: col.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: col, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "${currencyFormatter.format(val)} ৳",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionRow(DrawerTransaction tx) {
    bool isCredit = tx.type == 'sale' || tx.type == 'collection';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${DateFormat('dd MMM HH:mm').format(tx.date)} • ${tx.method}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${isCredit ? '+' : ''}${currencyFormatter.format(tx.amount)}",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green : Colors.red,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _filterBtn("Today", DateFilter.daily),
          const SizedBox(width: 8),
          _filterBtn("Month", DateFilter.monthly),
          const SizedBox(width: 8),
          _filterBtn("Year", DateFilter.yearly),
          const Spacer(),
          InkWell(
            onTap: () async {
              var res = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2022),
                lastDate: DateTime.now(),
              );
              if (res != null) controller.updateCustomDate(res);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: borderCol),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.calendar_month,
                size: 16,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? darkBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: sel ? darkBlue : borderCol),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: sel ? Colors.white : Colors.grey,
            ),
          ),
        ),
      );
    });
  }

  void _showAddDialog() {
    final amt = TextEditingController();
    final note = TextEditingController();
    final bankName = TextEditingController();
    final accNo = TextEditingController();
    String method = 'cash';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Manual Deposit",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amt,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: "Description",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: method,
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
                decoration: const InputDecoration(
                  labelText: "Target Account",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bankName,
                decoration: const InputDecoration(
                  labelText: "Bank/Provider Name (Optional)",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accNo,
                decoration: const InputDecoration(
                  labelText: "Reference/Acc No (Optional)",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (amt.text.isNotEmpty) {
                      controller.addManualCash(
                        amount: double.parse(amt.text),
                        method: method,
                        desc: note.text,
                        bankName: bankName.text,
                        accountNo: accNo.text,
                      );
                      Get.back();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: darkBlue),
                  child: const Text(
                    "DEPOSIT",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCashOutDialog() {
    final amt = TextEditingController();
    final bankName = TextEditingController();
    final accNo = TextEditingController();
    String method = 'bank';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Withdraw Funds",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: method,
                items:
                    ['bank', 'bkash', 'nagad', 'cash']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged: (v) => method = v!,
                decoration: const InputDecoration(
                  labelText: "Source",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amt,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bankName,
                decoration: const InputDecoration(
                  labelText: "Bank/Provider Name",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accNo,
                decoration: const InputDecoration(
                  labelText: "Ref/Cheque No",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
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
                    backgroundColor: Colors.orange[800],
                  ),
                  child: const Text(
                    "WITHDRAW",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}