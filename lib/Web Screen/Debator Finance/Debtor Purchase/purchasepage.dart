// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/dialog.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';
import 'package:intl/intl.dart';

class DebtorPurchasePage extends StatelessWidget {
  final String debtorId;
  final String debtorName;

  DebtorPurchasePage({
    super.key,
    required this.debtorId,
    required this.debtorName,
  });

  final DebtorPurchaseController controller = Get.put(
    DebtorPurchaseController(),
  );

  // THEME COLORS
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color creditRed = Color(0xFFEF4444);
  static const Color debitGreen = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadPurchases(debtorId);
    });

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Text(
          "Purchases: $debtorName",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: darkSlate,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. STATS HEADER
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            color: darkSlate,
            child: Row(
              children: [
                _statCard(
                  "Total Purchased",
                  controller.totalPurchased,
                  Colors.white,
                ),
                const SizedBox(width: 1), // Divider space
                Container(width: 1, height: 40, color: Colors.white24),
                const SizedBox(width: 20),
                _statCard("Total Paid", controller.totalPaid, debitGreen),
                const Spacer(),
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "PAYABLE DUE",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        "Tk ${controller.currentPayable.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: creditRed,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. ACTION BAR
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    label: "New Purchase",
                    icon: Icons.add_shopping_cart,
                    color: activeAccent,
                    onTap: () => showPurchaseDialog(context, debtorId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    label: "Pay Cash/Bank",
                    icon: Icons.payments,
                    color: debitGreen,
                    onTap: () => _showNormalPaymentDialog(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    label: "Adjust Contra",
                    icon: Icons.compare_arrows,
                    color: Colors.orange[800]!,
                    onTap: () => _showContraDialog(context),
                    isOutline: true,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. LIST HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.grey[100],
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "Date",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    "Description",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Amount",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. LIST
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.purchases.isEmpty) {
                return const Center(child: Text("No history found"));
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: controller.purchases.length,
                itemBuilder: (context, index) {
                  final item = controller.purchases[index];
                  // Determine visuals
                  final bool isInvoice = item['type'] == 'invoice';
                  final bool isAdj = item['type'] == 'adjustment';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Date
                        Expanded(
                          flex: 2,
                          child: Text(
                            DateFormat(
                              'dd MMM',
                            ).format((item['date'] as dynamic).toDate()),
                            style: const TextStyle(color: darkSlate),
                          ),
                        ),
                        // Desc
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isInvoice
                                        ? Icons.inventory_2_outlined
                                        : (isAdj
                                            ? Icons.compare_arrows
                                            : Icons.money_off),
                                    size: 14,
                                    color:
                                        isInvoice
                                            ? activeAccent
                                            : (isAdj
                                                ? Colors.orange
                                                : debitGreen),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isInvoice
                                        ? "Stock Purchase"
                                        : (isAdj
                                            ? "Ledger Adjustment"
                                            : "Payment Out"),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (item['note'] != null &&
                                  item['note'].toString().isNotEmpty)
                                Text(
                                  item['note'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Amount
                        Expanded(
                          flex: 2,
                          child: Text(
                            (isInvoice ? "+" : "-") +
                                (item['totalAmount'] ?? item['amount'])
                                    .toString(),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  isInvoice
                                      ? darkSlate
                                      : (isAdj ? Colors.orange : debitGreen),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _statCard(String label, RxDouble val, Color valColor) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val.value.toStringAsFixed(2),
            style: TextStyle(
              color: valColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isOutline = false,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16, color: isOutline ? color : Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: isOutline ? Colors.white : color,
        foregroundColor: isOutline ? color : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: isOutline ? BorderSide(color: color) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
    );
  }

  // --- DIALOGS ---

  void _showNormalPaymentDialog(BuildContext context) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Record Payment Out",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkSlate, // Uses your static const
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Pay Cash to this debtor. This will be recorded as an Expense.",
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(
                  labelText: "Note (Optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: debitGreen, // Uses your static const
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed:
                      () => controller.makePayment(
                        debtorId: debtorId,
                        debtorName: debtorName, // PASS THE NAME HERE
                        amount: double.tryParse(amountC.text) ?? 0,
                        method: "Cash",
                        note: noteC.text,
                      ),
                  child: const Text(
                    "Confirm Payment",
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

  void _showContraDialog(BuildContext context) {
    final amountC = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.compare_arrows, color: Colors.orange),
                  SizedBox(width: 10),
                  Text(
                    "Contra Adjustment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "This will deduct the amount from 'Payable Due' and also deduct from 'Receivable Due' in the Debtor's Sales Ledger.",
                  style: TextStyle(fontSize: 12, color: Colors.brown),
                ),
              ),
              const SizedBox(height: 20),
              Obx(
                () => Text(
                  "Max Adjust: ${controller.currentPayable}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Adjustment Amount",
                  border: OutlineInputBorder(),
                  prefixText: "Tk ",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkSlate,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed:
                      () => controller.processContraAdjustment(
                        debtorId: debtorId,
                        amount: double.tryParse(amountC.text) ?? 0,
                      ),
                  child: const Text(
                    "Process Adjustment",
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
