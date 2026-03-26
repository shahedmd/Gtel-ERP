// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpensecontroller.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/expensedatamodel.dart';
import 'package:intl/intl.dart';


class DailyExpensesPage extends StatelessWidget {
  final DailyExpensesController controller = Get.put(DailyExpensesController());

  // Professional Theme Colors (Sync with Sidebar)
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);

  DailyExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(context),
          _buildSummaryBar(),
          _buildTableHead(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.dailyList.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: activeAccent),
                );
              }

              if (controller.dailyList.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 0,
                ),
                itemCount: controller.dailyList.length,
                itemBuilder: (context, index) {
                  final expense = controller.dailyList[index];
                  return _ExpenseRow(expense: expense, controller: controller);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daily Expense Tracker",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: darkSlate,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  "Transactions for ${DateFormat('EEEE, dd MMMM yyyy').format(controller.selectedDate.value)}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),

          OutlinedButton.icon(
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: controller.selectedDate.value,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder:
                    (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: darkSlate,
                        ),
                      ),
                      child: child!,
                    ),
              );
              if (picked != null) controller.changeDate(picked);
            },
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text("Change Date"),
            style: OutlinedButton.styleFrom(
              foregroundColor: darkSlate,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),

          IconButton(
            onPressed: () => controller.generateDailyPDF(),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: "Export PDF",
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),

          ElevatedButton.icon(
            onPressed:
                () => Get.dialog(_AddExpenseDialog(controller: controller)),
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text(
              "Record Expense",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SUMMARY BAR ---
  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              FontAwesomeIcons.wallet,
              color: activeAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            "TOTAL EXPENDITURE TODAY",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Obx(
            () => Text(
              "৳ ${controller.dailyTotal.value.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: darkSlate,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TABLE HEADER ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Very light slate
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: _headText("TIME")),
          Expanded(flex: 3, child: _headText("EXPENSE DESCRIPTION")),
          Expanded(flex: 3, child: _headText("NOTE / REMARKS")),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: _headText("AMOUNT"),
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _headText(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF64748B),
      fontWeight: FontWeight.w800,
      fontSize: 11,
      letterSpacing: 0.5,
    ),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No expenses recorded today.",
            style: TextStyle(
              color: textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// MEMORY SAFE TABLE ROW (Stateful for Hover Effects)
// ==================================================
class _ExpenseRow extends StatefulWidget {
  final ExpenseModel expense;
  final DailyExpensesController controller;

  const _ExpenseRow({required this.expense, required this.controller});

  @override
  State<_ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends State<_ExpenseRow> {
  bool isHovered = false;

  void _handleDelete() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Confirm Deletion",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DailyExpensesPage.darkSlate,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: DailyExpensesPage.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: "Are you sure you want to delete the entry ",
                    ),
                    TextSpan(
                      text: "'${widget.expense.name}'",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DailyExpensesPage.darkSlate,
                      ),
                    ),
                    const TextSpan(
                      text:
                          "? This will instantly update your monthly reports.",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Keep Entry",
                        style: TextStyle(
                          color: DailyExpensesPage.darkSlate,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        widget.controller.deleteDaily(widget.expense.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Delete Forever",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                DateFormat('hh:mm a').format(widget.expense.time),
                style: const TextStyle(
                  color: DailyExpensesPage.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.expense.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: DailyExpensesPage.darkSlate,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.expense.note.isEmpty ? "-" : widget.expense.note,
                style: const TextStyle(
                  color: DailyExpensesPage.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                "৳ ${widget.expense.amount.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: DailyExpensesPage.darkSlate,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  tooltip: "Delete Record",
                  splashRadius: 20,
                  onPressed: _handleDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// MEMORY SAFE DIALOG (Stateful to prevent lag/leaks)
// ==================================================
class _AddExpenseDialog extends StatefulWidget {
  final DailyExpensesController controller;
  const _AddExpenseDialog({required this.controller});

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  late TextEditingController nameC, amountC, noteC;
  late DateTime addDate;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController();
    amountC = TextEditingController();
    noteC = TextEditingController();
    addDate = widget.controller.selectedDate.value;
  }

  @override
  void dispose() {
    // CRITICAL: Prevent Memory Leaks
    nameC.dispose();
    amountC.dispose();
    noteC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameC.text.trim().isEmpty || amountC.text.trim().isEmpty) {
      Get.snackbar(
        "Error",
        "Name and Amount are required",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final double parsedAmount = double.tryParse(amountC.text.trim()) ?? 0.0;
    if (parsedAmount <= 0) {
      Get.snackbar(
        "Error",
        "Enter a valid amount greater than 0",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => isSaving = true);

    await widget.controller.addDailyExpense(
      nameC.text.trim(),
      parsedAmount, // Send as double!
      note: noteC.text.trim(),
      date: addDate,
    );

    // We do NOT use Get.back() inside the controller anymore.
    // We close the dialog right here locally when the await finishes.
    if (mounted) {
      Get.back();
    }
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
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: DailyExpensesPage.textMuted),
        filled: true,
        fillColor: DailyExpensesPage.bgGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DailyExpensesPage.activeAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Record New Expense",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DailyExpensesPage.darkSlate,
              ),
            ),
            const SizedBox(height: 24),
            _buildField(nameC, "What was the expense for?", Icons.edit),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    amountC,
                    "Amount (৳)",
                    Icons.payments,
                    type: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      DateTime? p = await showDatePicker(
                        context: context,
                        initialDate: addDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder:
                            (context, child) => Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: DailyExpensesPage.darkSlate,
                                ),
                              ),
                              child: child!,
                            ),
                      );
                      if (p != null) setState(() => addDate = p);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('dd MMM yyyy').format(addDate)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DailyExpensesPage.darkSlate,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: Colors.black12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildField(noteC, "Note (Optional)", Icons.notes),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSaving ? null : () => Get.back(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: DailyExpensesPage.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DailyExpensesPage.activeAccent,
                    minimumSize: const Size(150, 52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Save Expense",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}