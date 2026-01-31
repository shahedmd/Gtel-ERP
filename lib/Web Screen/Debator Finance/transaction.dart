// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'debatorcontroller.dart';

// Theme Constants
const Color darkSlate = Color(0xFF111827);
const Color activeAccent = Color(0xFF3B82F6);
const Color creditRed = Color(0xFFEF4444); // For Credit/Debt
const Color debitGreen = Color(0xFF10B981); // For Debit/Payment
const Color bgGrey = Color(0xFFF3F4F6);
const Color textMuted = Color(0xFF6B7280);

void addTransactionDialog(DebatorController controller, String id) {
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final Rx<DateTime> selectedDate = Rx<DateTime>(DateTime.now());

  // --- NEW: Dynamic Payment States ---
  final RxString payMethodType = 'cash'.obs; // cash, bank, bkash, nagad, rocket
  final bankNameC = TextEditingController();
  final accountNoC = TextEditingController();
  final mobileNoC = TextEditingController();

  // Find the debtor using the Model (for name display)
  final debtor = controller.bodies.firstWhere((d) => d.id == id);

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500, // Professional fixed width for Desktop/Web
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADER ---
              _buildDialogHeader(debtor.name),

              if (controller.gbIsLoading.value)
                const LinearProgressIndicator(
                  backgroundColor: bgGrey,
                  color: activeAccent,
                ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Transaction Details"),
                      _buildField(
                        amountC,
                        "Amount (Tk)",
                        FontAwesomeIcons.coins,
                        type: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        noteC,
                        "Note / Bill Reference",
                        FontAwesomeIcons.noteSticky,
                      ),

                      const SizedBox(height: 24),
                      _sectionLabel("Date & Payment Method"),

                      // Date & Method Selector Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDatePicker(selectedDate)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMethodTypeDropdown(payMethodType),
                          ),
                        ],
                      ),

                      // Dynamic Inputs based on Method
                      const SizedBox(height: 12),
                      _buildDynamicPaymentInputs(
                        payMethodType.value,
                        bankNameC,
                        accountNoC,
                        mobileNoC,
                      ),

                      const SizedBox(height: 30),
                      _sectionLabel("Select Transaction Type"),

                      // --- ACTION BUTTONS ---
                      Row(
                        children: [
                          // CREDIT BUTTON (Bill/Sale)
                          Expanded(
                            child: _actionButton(
                              label: "Take Bill (Credit)",
                              icon: FontAwesomeIcons.fileInvoice,
                              color: creditRed,
                              isLoading: controller.gbIsLoading.value,
                              onTap: () {
                                // For Credit, payment details are usually ignored by controller/sales logic
                                // but we pass them just in case logic changes.
                                _processTx(
                                  controller,
                                  id,
                                  amountC,
                                  noteC,
                                  "credit",
                                  selectedDate,
                                  payMethodType,
                                  bankNameC,
                                  accountNoC,
                                  mobileNoC,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // DEBIT BUTTON (Payment Received)
                          Expanded(
                            child: _actionButton(
                              label: "Receive Pay (Debit)",
                              icon: FontAwesomeIcons.moneyCheck,
                              color: debitGreen,
                              isLoading: controller.gbIsLoading.value,
                              onTap: () {
                                _processTx(
                                  controller,
                                  id,
                                  amountC,
                                  noteC,
                                  "debit",
                                  selectedDate,
                                  payMethodType,
                                  bankNameC,
                                  accountNoC,
                                  mobileNoC,
                                );
                              },
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
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// --- UI HELPERS ---

Widget _buildDialogHeader(String name) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    decoration: const BoxDecoration(
      color: darkSlate,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    child: Row(
      children: [
        const Icon(FontAwesomeIcons.exchangeAlt, color: Colors.white, size: 18),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "New Ledger Entry",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Debtor: $name",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
        ),
      ],
    ),
  );
}

Widget _buildDatePicker(Rx<DateTime> date) {
  return Obx(
    () => InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: Get.context!,
          initialDate: date.value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) date.value = picked;
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: bgGrey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: activeAccent),
            const SizedBox(width: 10),
            Text(
              DateFormat('dd MMM yyyy').format(date.value),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

// Replaces the old dropdown with simple Method Type Selector
Widget _buildMethodTypeDropdown(RxString methodType) {
  return Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: bgGrey,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: methodType.value,
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: 'cash',
            child: Row(
              children: [
                Icon(Icons.money, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text("Cash"),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'bank',
            child: Row(
              children: [
                Icon(Icons.account_balance, size: 16, color: Colors.indigo),
                SizedBox(width: 8),
                Text("Bank"),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'bkash',
            child: Row(
              children: [
                Icon(Icons.mobile_friendly, size: 16, color: Colors.pink),
                SizedBox(width: 8),
                Text("Bkash"),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'nagad',
            child: Row(
              children: [
                Icon(Icons.mobile_friendly, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Text("Nagad"),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'rocket',
            child: Row(
              children: [
                Icon(Icons.mobile_friendly, size: 16, color: Colors.purple),
                SizedBox(width: 8),
                Text("Rocket"),
              ],
            ),
          ),
        ],
        onChanged: (v) => methodType.value = v!,
      ),
    ),
  );
}

// NEW: Conditional inputs for Bank/Mobile
Widget _buildDynamicPaymentInputs(
  String type,
  TextEditingController bankC,
  TextEditingController accC,
  TextEditingController mobC,
) {
  if (type == 'bank') {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: activeAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activeAccent.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildField(bankC, "Bank Name (e.g. City Bank)", Icons.business),
          const SizedBox(height: 8),
          _buildField(accC, "Account Number", Icons.numbers),
        ],
      ),
    );
  } else if (['bkash', 'nagad', 'rocket'].contains(type)) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.1)),
      ),
      child: _buildField(
        mobC,
        "${type.capitalizeFirst} Number",
        Icons.phone_android,
        type: TextInputType.number,
      ),
    );
  }
  return const SizedBox.shrink(); // Empty for Cash
}

Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required bool isLoading,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: isLoading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isLoading ? color.withOpacity(0.5) : color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          FaIcon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

// --- LOGIC ---

void _processTx(
  DebatorController c,
  String id,
  TextEditingController amt,
  TextEditingController note,
  String type,
  Rx<DateTime> date,
  // New Params
  RxString payType,
  TextEditingController bankC,
  TextEditingController accC,
  TextEditingController mobC,
) async {
  double amount = double.tryParse(amt.text) ?? 0;
  if (amount <= 0) {
    Get.snackbar("Error", "Enter valid amount");
    return;
  }

  // Construct Dynamic Map
  Map<String, dynamic> finalPaymentData = {'type': 'cash'};
  String method = payType.value;

  if (method == 'bank') {
    if (bankC.text.isEmpty) {
      Get.snackbar("Error", "Enter Bank Name");
      return;
    }
    finalPaymentData = {
      'type': 'bank',
      'bankName': bankC.text.trim(),
      'accountNumber': accC.text.trim(),
    };
  } else if (['bkash', 'nagad', 'rocket'].contains(method)) {
    if (mobC.text.isEmpty) {
      Get.snackbar("Error", "Enter Mobile Number");
      return;
    }
    finalPaymentData = {'type': method, 'number': mobC.text.trim()};
  } else {
    finalPaymentData = {'type': 'cash'};
  }

  // Execute Transaction
  await c.addTransaction(
    debtorId: id,
    amount: amount,
    note: note.text,
    type: type,
    date: date.value,
    paymentMethodData: finalPaymentData, // Updated param name
  );

  if (Get.isDialogOpen ?? false) {
    Get.back();
  }
}

// Reuse the standard helpers for UI consistency
Widget _sectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: activeAccent,
        letterSpacing: 1.1,
      ),
    ),
  );
}

Widget _buildField(
  TextEditingController c,
  String hint,
  IconData icon, {
  TextInputType type = TextInputType.text,
}) {
  return TextField(
    controller: c,
    keyboardType: type,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 16, color: Colors.grey),
      filled: true,
      fillColor: bgGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
