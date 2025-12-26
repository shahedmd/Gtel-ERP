// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dailycontroller.dart';
import 'expensemodel.dart';

class DailyExpensesPage extends StatelessWidget {
  final DailyExpensesController controller = Get.put(DailyExpensesController());

  // Professional Theme Colors (Sync with Sidebar)
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

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
              if (controller.isLoading.value) {
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
                  vertical: 4,
                ),
                itemCount: controller.dailyList.length,
                itemBuilder: (context, index) {
                  final expense = controller.dailyList[index];
                  return _buildExpenseRow(expense);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- TOP HEADER (Title & Date Picker) ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daily Expense Tracker",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              Obx(
                () => Text(
                  "Transactions for ${DateFormat('EEEE, dd MMMM yyyy').format(controller.selectedDate.value)}",
                  style: const TextStyle(fontSize: 14, color: textMuted),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Date Selector
          OutlinedButton.icon(
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: controller.selectedDate.value,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) controller.changeDate(picked);
            },
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text("Change Date"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // PDF Export
          IconButton(
            onPressed: () => controller.generateDailyPDF(),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: "Export PDF",
          ),
          const SizedBox(width: 12),
          // Add Button
          ElevatedButton.icon(
            onPressed: () => _showAddExpenseDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Record Expense",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SUMMARY BAR (Total Display) ---
  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: activeAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activeAccent.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(FontAwesomeIcons.wallet, color: activeAccent, size: 20),
          const SizedBox(width: 16),
          const Text(
            "TOTAL EXPENDITURE TODAY",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Obx(
            () => Text(
              "৳ ${controller.dailyTotal.value.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: activeAccent,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 1,
            child: Text(
              "Time",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Expense Description",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Note / Remarks",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Amount",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 60), // Space for Delete Action
        ],
      ),
    );
  }

  Widget _buildExpenseRow(ExpenseModel expense) {
    // Ensure the type is ExpenseModel
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          // Time
          Expanded(
            flex: 1,
            child: Text(
              DateFormat('hh:mm a').format(expense.time),
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
          // Name
          Expanded(
            flex: 3,
            child: Text(
              expense.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: darkSlate,
              ),
            ),
          ),
          // Note
          Expanded(
            flex: 3,
            child: Text(
              expense.note.isEmpty ? "-" : expense.note,
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              "৳ ${expense.amount.toStringAsFixed(2)}",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
          ),

          // --- UPDATED DELETE BUTTON ---
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: "Delete Record",
              onPressed: () => _handleDelete(expense), // Calls the new method
            ),
          ),
        ],
      ),
    );
  }

void _showAddExpenseDialog() {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final Rx<DateTime> addDate = controller.selectedDate.value.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Record New Expense",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildField(nameC, "What was the expense for?", Icons.edit),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      amountC,
                      "Amount",
                      Icons.payments,
                      type: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
                        onPressed: () async {
                          DateTime? p = await showDatePicker(
                            context: Get.context!,
                            initialDate: addDate.value,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (p != null) addDate.value = p;
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('dd MMM').format(addDate.value)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildField(noteC, "Note (Optional)", Icons.notes),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Button: Disable if loading
                  Obx(() => TextButton(
                    onPressed: controller.isLoading.value ? null : () => Get.back(),
                    child: const Text("Cancel"),
                  )),
                  const SizedBox(width: 12),
                  
                  // Save Button with Loading Indicator
                  Obx(() => ElevatedButton(
                    onPressed: controller.isLoading.value 
                        ? null // Prevent double-clicks
                        : () async {
                            if (nameC.text.isEmpty || amountC.text.isEmpty) {
                              Get.snackbar("Error", "Name and Amount are required");
                              return;
                            }
                            
                            // Execute Add
                            await controller.addDailyExpense(
                              nameC.text,
                              int.parse(amountC.text),
                              note: noteC.text,
                              date: addDate.value,
                            );
                            
                            // Only close the dialog if the loading finished successfully
                            if (!controller.isLoading.value) {
                              Get.back();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeAccent,
                      minimumSize: const Size(150, 56), // Fixed width to prevent jumping
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: controller.isLoading.value
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
                            ),
                          ),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false, 
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
        prefixIcon: Icon(icon, size: 18, color: textMuted),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.receipt_long, size: 64, color: Colors.black12),
          SizedBox(height: 16),
          Text(
            "No transactions recorded for this date.",
            style: TextStyle(color: textMuted),
          ),
        ],
      ),
    );
  }

  // --- DELETE HANDLER ---
  void _handleDelete(ExpenseModel expense) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Confirm Deletion",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: "Are you sure you want to delete the entry ",
                    ),
                    TextSpan(
                      text: "'${expense.name}'",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                      ),
                    ),
                    const TextSpan(
                      text: "? This will also update your monthly reports.",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Keep Entry",
                        style: TextStyle(color: darkSlate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back(); // Close Dialog
                        await controller.deleteDaily(expense.id);
                        // The UI updates automatically because dailyList is an RxList
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 18),
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
      barrierDismissible: true,
    );
  }
}
