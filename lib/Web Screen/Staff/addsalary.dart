// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import '../Expenses/dailycontroller.dart'; // Ensure correct path

// Consistent Professional Theme
const Color darkSlate = Color(0xFF111827);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF3F4F6);

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
  final DailyExpensesController expensesController =
      Get.find<DailyExpensesController>();

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
            _buildHeader(staffName),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            "Salary Month",
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

                    _sectionLabel("Transaction Date"),
                    _buildDatePicker(selectedDate),
                  ],
                ),
              ),
            ),

            // --- FOOTER ACTIONS ---
            _buildFooter(
              onCancel: () => Get.back(),
              onSave:
                  () => _handleSalaryTransaction(
                    controller,
                    expensesController,
                    staffId,
                    staffName,
                    amountC,
                    monthC,
                    noteC,
                    selectedDate,
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

Widget _buildHeader(String name) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: darkSlate,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          FontAwesomeIcons.fileInvoiceDollar,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Disburse Salary",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Paying: $name",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
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
}) {
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
            backgroundColor: activeAccent,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "Process Payment",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

// --- TRANSACTION LOGIC ---

Future<void> _handleSalaryTransaction(
  StaffController staffCtrl,
  DailyExpensesController expCtrl,
  String staffId,
  String staffName,
  TextEditingController amountC,
  TextEditingController monthC,
  TextEditingController noteC,
  Rx<DateTime?> date,
) async {
  // 1. Validation
  if (amountC.text.isEmpty || monthC.text.isEmpty || date.value == null) {
    Get.snackbar(
      "Missing Info",
      "Amount and Month are required.",
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return;
  }

  final double? amount = double.tryParse(amountC.text);
  if (amount == null || amount <= 0) {
    Get.snackbar("Invalid Amount", "Please enter a valid salary figure.");
    return;
  }

  try {
    // 2. Perform Dual Update (Staff Record + Expense Record)
    // We use Get.showOverlay to prevent user interaction during the dual write
    await Get.showOverlay(
      asyncFunction: () async {
        // Step A: Add to Staff Sub-collection
        await staffCtrl.addSalary(
          staffId,
          amount,
          noteC.text,
          monthC.text,
          date.value!,
        );

        // Step B: Add to Global Daily Expenses
        await expCtrl.addDailyExpense(
          "Salary: $staffName (${monthC.text})",
          amount.toInt(),
          note: "Staff ID: $staffId. ${noteC.text}",
          date: date.value,
        );
      },
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: activeAccent),
      ),
    );

    Get.back(); // Close Dialog
    Get.snackbar(
      "Success",
      "Salary processed and expense recorded.",
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  } catch (e) {
    Get.snackbar(
      "Transaction Failed",
      e.toString(),
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}

// Reuse buildField and sectionLabel from the AddStaff refactor for consistency

// --- HELPER COMPONENTS FOR DIALOGS ---

/// Creates a small, uppercase blue label for form sections
Widget _sectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF3B82F6), // Matches activeAccent
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
