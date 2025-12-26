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

void addTransactionDialog(DebatorController controller, String id) {
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final Rx<DateTime> selectedDate = Rx<DateTime>(DateTime.now());
  final Rx<Map<String, dynamic>?> selectedPayment = Rx<Map<String, dynamic>?>(
    null,
  );

  // Find the debtor using the Model
  final debtor = controller.bodies.firstWhere((d) => d.id == id);
  final payments = debtor.payments;

  // Set default payment if available
  if (payments.isNotEmpty) {
    selectedPayment.value = payments.first;
  }

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
                      _sectionLabel("Schedule & Method"),

                      // Date & Payment Method Row
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(selectedDate)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPaymentDropdown(
                              payments,
                              selectedPayment,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      _buildPaymentInfo(selectedPayment),

                      const SizedBox(height: 30),
                      _sectionLabel("Select Transaction Type"),

                      // --- ACTION BUTTONS ---
                      Row(
                        children: [
                          // CREDIT BUTTON
                          Expanded(
                            child: _actionButton(
                              label: "Take Bill (Credit)",
                              icon: FontAwesomeIcons.fileInvoice,
                              color: creditRed,
                              isLoading: controller.gbIsLoading.value,
                              onTap:
                                  () => _processTx(
                                    controller,
                                    id,
                                    amountC,
                                    noteC,
                                    "credit",
                                    selectedDate,
                                    selectedPayment,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // DEBIT BUTTON
                          Expanded(
                            child: _actionButton(
                              label: "Receive Pay (Debit)",
                              icon: FontAwesomeIcons.moneyCheck,
                              color: debitGreen,
                              isLoading: controller.gbIsLoading.value,
                              onTap:
                                  () => _processTx(
                                    controller,
                                    id,
                                    amountC,
                                    noteC,
                                    "debit",
                                    selectedDate,
                                    selectedPayment,
                                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bgGrey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: activeAccent),
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

Widget _buildPaymentDropdown(
  List<Map<String, dynamic>> payments,
  Rx<Map<String, dynamic>?> selected,
) {
  return Obx(
    () => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: selected.value,
          isExpanded: true,
          hint: const Text("Method", style: TextStyle(fontSize: 13)),
          items:
              payments.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(
                    p['type']?.toString().toUpperCase() ?? "UNKNOWN",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (v) => selected.value = v,
        ),
      ),
    ),
  );
}

Widget _buildPaymentInfo(Rx<Map<String, dynamic>?> pm) {
  return Obx(() {
    if (pm.value == null) return const SizedBox();
    pm.value!['type']?.toString().toLowerCase();
    String info = pm.value!['number'] ?? pm.value!['accountNumber'] ?? "";
    if (info.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: activeAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: activeAccent),
          const SizedBox(width: 8),
          Text(
            "Account: $info",
            style: const TextStyle(
              fontSize: 12,
              color: activeAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  });
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
  Rx<Map<String, dynamic>?> pm,
) async {
  double amount = double.tryParse(amt.text) ?? 0;
  if (amount <= 0) {
    Get.snackbar("Error", "Enter valid amount");
    return;
  }

  // 2. Execute Transaction and WAIT for it to finish
  await c.addTransaction(
    debtorId: id,
    amount: amount,
    note: note.text,
    type: type,
    date: date.value,
    selectedPaymentMethod: pm.value,
  );

  // 3. Close the dialog ONLY if the transaction finished successfully
  // We check Get.isDialogOpen to ensure we don't call Get.back() if it's already closed
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
    ),
  );
}
