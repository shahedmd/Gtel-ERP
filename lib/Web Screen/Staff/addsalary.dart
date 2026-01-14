// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controller.dart'; // Imports StaffController & Enums

// Consistent Professional Theme
const Color darkSlate = Color(0xFF111827);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF3F4F6);
const Color creditGreen = Color(0xFF10B981); // For Repayments
const Color debtRed = Color(0xFFEF4444); // For Advances

void addSalaryDialog(
  StaffController controller,
  String staffId,
  String staffName,
) {
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final monthC = TextEditingController(
    text: DateFormat(
      'MMMM yyyy',
    ).format(DateTime.now()), // Auto-fill current month
  );

  final Rx<DateTime?> selectedDate = Rx<DateTime?>(DateTime.now());

  // NEW: State for Transaction Type (Salary, Advance, Repayment)
  final Rx<StaffTransactionType> selectedType = StaffTransactionType.SALARY.obs;

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500, // Professional Desktop Width
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Obx(() => _buildHeader(staffName, selectedType.value)),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Transaction Type Selector
                    _sectionLabel("Transaction Type"),
                    _buildTypeSelector(selectedType),
                    const SizedBox(height: 20),

                    // 2. Payment Details
                    _sectionLabel("Payment Details"),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildField(
                            amountC,
                            "Amount (Tk)",
                            FontAwesomeIcons.coins,
                            type: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildField(
                            monthC,
                            "Month / Ref",
                            FontAwesomeIcons.calendarDay,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      noteC,
                      "Transaction Note (Optional)",
                      FontAwesomeIcons.stickyNote,
                    ),
                    const SizedBox(height: 24),

                    // 3. Date Selection
                    _sectionLabel("Transaction Date"),
                    _buildDatePicker(selectedDate),
                  ],
                ),
              ),
            ),

            // --- FOOTER ACTIONS ---
            Obx(
              () => _buildFooter(
                onCancel: () => Get.back(),
                type: selectedType.value,
                onSave:
                    () => _handleTransaction(
                      controller,
                      staffId,
                      staffName,
                      amountC,
                      monthC,
                      noteC,
                      selectedDate,
                      selectedType.value,
                    ),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// --- UI COMPONENTS ---

Widget _buildHeader(String name, StaffTransactionType type) {
  // Dynamic Title based on selection
  String title = "Disburse Salary";
  Color color = darkSlate;
  IconData icon = FontAwesomeIcons.fileInvoiceDollar;

  if (type == StaffTransactionType.ADVANCE) {
    title = "Give Advance (Loan)";
    color = debtRed;
    icon = FontAwesomeIcons.handHoldingDollar;
  } else if (type == StaffTransactionType.REPAYMENT) {
    title = "Record Repayment";
    color = creditGreen;
    icon = FontAwesomeIcons.moneyBillTransfer;
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Staff: $name",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.close, color: Colors.white54),
        ),
      ],
    ),
  );
}

// NEW: Segmented Control for Transaction Type
Widget _buildTypeSelector(Rx<StaffTransactionType> selectedType) {
  return Obx(
    () => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          _typeButton("Salary", StaffTransactionType.SALARY, selectedType),
          _typeButton("Advance", StaffTransactionType.ADVANCE, selectedType),
          _typeButton(
            "Repayment",
            StaffTransactionType.REPAYMENT,
            selectedType,
          ),
        ],
      ),
    ),
  );
}

Widget _typeButton(
  String label,
  StaffTransactionType type,
  Rx<StaffTransactionType> current,
) {
  final isSelected = current.value == type;
  Color activeColor = activeAccent;
  if (type == StaffTransactionType.ADVANCE) activeColor = debtRed;
  if (type == StaffTransactionType.REPAYMENT) activeColor = creditGreen;

  return Expanded(
    child: InkWell(
      onTap: () => current.value = type,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ]
                  : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : Colors.grey[600],
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

Widget _buildDatePicker(Rx<DateTime?> selectedDate) {
  return Obx(
    () => InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: Get.context!,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) selectedDate.value = picked;
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgGrey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(
              FontAwesomeIcons.calendarCheck,
              size: 16,
              color: activeAccent,
            ),
            const SizedBox(width: 12),
            Text(
              selectedDate.value != null
                  ? DateFormat('dd MMMM yyyy').format(selectedDate.value!)
                  : "Select Date",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: darkSlate,
              ),
            ),
            const Spacer(),
            const Icon(Icons.edit, size: 14, color: activeAccent),
          ],
        ),
      ),
    ),
  );
}

Widget _buildFooter({
  required VoidCallback onCancel,
  required VoidCallback onSave,
  required StaffTransactionType type,
}) {
  String btnLabel = "Process Payment";
  Color btnColor = activeAccent;

  if (type == StaffTransactionType.ADVANCE) {
    btnLabel = "Record Advance";
    btnColor = debtRed;
  } else if (type == StaffTransactionType.REPAYMENT) {
    btnLabel = "Confirm Repayment";
    btnColor = creditGreen;
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: bgGrey)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            btnLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

// --- TRANSACTION LOGIC (UPDATED) ---

Future<void> _handleTransaction(
  StaffController staffCtrl,
  String staffId,
  String staffName,
  TextEditingController amountC,
  TextEditingController monthC,
  TextEditingController noteC,
  Rx<DateTime?> date,
  StaffTransactionType type,
) async {
  // 1. Validation
  if (amountC.text.isEmpty || date.value == null) {
    Get.snackbar(
      "Missing Info",
      "Amount and Date are required.",
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return;
  }

  final double? amount = double.tryParse(amountC.text);
  if (amount == null || amount <= 0) {
    Get.snackbar("Invalid Amount", "Please enter a valid numeric amount.");
    return;
  }

  // 2. Determine Note
  String finalNote = noteC.text;
  if (finalNote.isEmpty) {
    finalNote =
        type == StaffTransactionType.SALARY
            ? "Monthly Salary"
            : type == StaffTransactionType.ADVANCE
            ? "Advance Payment"
            : "Loan Repayment";
  }

  // 3. Perform Transaction (Controller handles DB + Daily Expenses)
  // We do NOT call dailyExpensesController here manually anymore.
  await staffCtrl.addTransaction(
    staffId: staffId,
    staffName: staffName,
    amount: amount,
    note: finalNote,
    date: date.value!,
    type: type,
    month: monthC.text, // Passed for reference
  );
}

// --- HELPER COMPONENTS ---

/// Creates a small, uppercase blue label for form sections
Widget _sectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6B7280), // Muted Text for labels
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// A professional ERP-styled text field
Widget _buildField(
  TextEditingController c,
  String hint,
  IconData icon, {
  TextInputType type = TextInputType.text,
}) {
  return TextField(
    controller: c,
    keyboardType: type,
    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)), // darkSlate
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      prefixIcon: Icon(icon, size: 16, color: Colors.blueGrey),
      filled: true,
      fillColor: const Color(0xFFF3F4F6), // bgGrey
      contentPadding: const EdgeInsets.symmetric(vertical: 16),

      // Default Border
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),

      // Border when not focused
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),

      // Border when user is typing
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF3B82F6), // activeAccent
          width: 1.5,
        ),
      ),
    ),
  );
}
