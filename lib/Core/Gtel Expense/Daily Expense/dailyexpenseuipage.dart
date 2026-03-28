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
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(context, isMobile),
          _buildSummaryBar(isMobile),
          if (!isMobile) _buildTableHead(),
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

              return ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 16 : 0,
                ),
                itemCount: controller.dailyList.length,
                separatorBuilder:
                    (context, index) =>
                        isMobile
                            ? const SizedBox(height: 12)
                            : const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final expense = controller.dailyList[index];
                  return isMobile
                      ? _MobileExpenseCard(
                        expense: expense,
                        controller: controller,
                      )
                      : _DesktopExpenseRow(
                        expense: expense,
                        controller: controller,
                      );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 20,
      ),
      color: Colors.white,
      child:
          isMobile
              ? _buildMobileHeaderContent(context)
              : _buildDesktopHeaderContent(context),
    );
  }

  Widget _buildDesktopHeaderContent(BuildContext context) {
    return Row(
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
          onPressed: () => _selectDate(context),
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
          onPressed: () => _openAddExpenseDialog(context),
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text(
            "Record Expense",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildMobileHeaderContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Daily Expenses",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: darkSlate,
              ),
            ),
            IconButton(
              onPressed: () => controller.generateDailyPDF(),
              icon: const FaIcon(
                FontAwesomeIcons.filePdf,
                color: Colors.redAccent,
                size: 18,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Obx(
          () => Text(
            DateFormat(
              'EEEE, dd MMM yyyy',
            ).format(controller.selectedDate.value),
            style: const TextStyle(
              fontSize: 13,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text("Date", style: TextStyle(fontSize: 13),),
                style: OutlinedButton.styleFrom(
                  foregroundColor: darkSlate,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openAddExpenseDialog(context),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text(
                  "Record",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openAddExpenseDialog(BuildContext context) {
    // We use GetBuilder to instantly initialize and inject the form controller
    // It automatically calls .dispose() on the controller when the dialog closes.
    Get.dialog(
      GetBuilder<AddExpenseFormController>(
        init: AddExpenseFormController(controller),
        builder: (formCtrl) => _AddExpenseDialog(formCtrl: formCtrl),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDate.value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: darkSlate),
            ),
            child: child!,
          ),
    );
    if (picked != null) controller.changeDate(picked);
  }

  // --- SUMMARY BAR ---
  Widget _buildSummaryBar(bool isMobile) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 16 : 20,
        isMobile ? 16 : 24,
        16,
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              FontAwesomeIcons.wallet,
              color: activeAccent,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TOTAL EXPENDITURE",
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                Obx(
                  () => Text(
                    "৳ ${controller.dailyTotal.value.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w800,
                      color: darkSlate,
                      letterSpacing: -1,
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

  // --- TABLE HEADER (Desktop Only) ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
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
// DESKTOP TABLE ROW (100% GetX - No setState)
// ==================================================
class _DesktopExpenseRow extends StatelessWidget {
  final ExpenseModel expense;
  final DailyExpensesController controller;

  // Local Rx variable for hover effect
  final RxBool isHovered = false.obs;

  _DesktopExpenseRow({required this.expense, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      child: Obx(
        () => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isHovered.value ? const Color(0xFFF8FAFC) : Colors.white,
            border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  DateFormat('hh:mm a').format(expense.time),
                  style: const TextStyle(
                    color: DailyExpensesPage.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  expense.name,
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
                  expense.note.isEmpty ? "-" : expense.note,
                  style: const TextStyle(
                    color: DailyExpensesPage.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "৳ ${expense.amount.toStringAsFixed(2)}",
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
                    onPressed: () => _handleDelete(expense, controller),
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

// ==================================================
// MOBILE CARD (Stateless)
// ==================================================
class _MobileExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final DailyExpensesController controller;

  const _MobileExpenseCard({required this.expense, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    expense.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: DailyExpensesPage.darkSlate,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _handleDelete(expense, controller),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(expense.time),
                      style: const TextStyle(
                        fontSize: 12,
                        color: DailyExpensesPage.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "৳ ${expense.amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: DailyExpensesPage.activeAccent,
                      ),
                    ),
                  ],
                ),
                if (expense.note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  const Text(
                    "Note / Remarks",
                    style: TextStyle(
                      fontSize: 10,
                      color: DailyExpensesPage.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.note,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DailyExpensesPage.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SHARED DELETE HANDLER ---
void _handleDelete(ExpenseModel expense, DailyExpensesController controller) {
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
                    text: "'${expense.name}'",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DailyExpensesPage.darkSlate,
                    ),
                  ),
                  const TextSpan(
                    text: "? This will instantly update your monthly reports.",
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
                      controller.deleteDaily(expense.id);
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

// ==================================================
// 100% GETX DIALOG CONTROLLER (Memory Safe)
// ==================================================
class AddExpenseFormController extends GetxController {
  final DailyExpensesController mainCtrl;
  AddExpenseFormController(this.mainCtrl);

  final nameC = TextEditingController();
  final amountC = TextEditingController();
  final noteC = TextEditingController();

  late final Rx<DateTime> addDate;
  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    addDate = mainCtrl.selectedDate.value.obs;
  }

  @override
  void onClose() {
    // Guaranteed to fire and clear RAM when dialog is closed
    nameC.dispose();
    amountC.dispose();
    noteC.dispose();
    super.onClose();
  }

  Future<void> saveExpense() async {
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

    isSaving.value = true;

    await mainCtrl.addDailyExpense(
      nameC.text.trim(),
      parsedAmount,
      note: noteC.text.trim(),
      date: addDate.value,
    );

    Get.back(); // Closes dialog, which triggers onClose() above
  }
}

// ==================================================
// DIALOG UI (Stateless + Obx)
// ==================================================
class _AddExpenseDialog extends StatelessWidget {
  final AddExpenseFormController formCtrl;

  const _AddExpenseDialog({required this.formCtrl});

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
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 500,
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: SingleChildScrollView(
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
              _buildField(
                formCtrl.nameC,
                "What was the expense for?",
                Icons.edit,
              ),
              const SizedBox(height: 16),

              if (isMobile) ...[
                _buildField(
                  formCtrl.amountC,
                  "Amount (৳)",
                  Icons.payments,
                  type: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildDateSelector(context),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        formCtrl.amountC,
                        "Amount (৳)",
                        Icons.payments,
                        type: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDateSelector(context)),
                  ],
                ),

              const SizedBox(height: 16),
              _buildField(formCtrl.noteC, "Note (Optional)", Icons.notes),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Obx(
                    () => TextButton(
                      onPressed:
                          formCtrl.isSaving.value ? null : () => Get.back(),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: DailyExpensesPage.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Obx(
                    () => ElevatedButton(
                      onPressed:
                          formCtrl.isSaving.value ? null : formCtrl.saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DailyExpensesPage.activeAccent,
                        minimumSize: const Size(140, 52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          formCtrl.isSaving.value
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                "Save",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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

  Widget _buildDateSelector(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        DateTime? p = await showDatePicker(
          context: context,
          initialDate: formCtrl.addDate.value,
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
        if (p != null) formCtrl.addDate.value = p;
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Obx(
        () => Text(DateFormat('dd MMM yyyy').format(formCtrl.addDate.value)),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: DailyExpensesPage.darkSlate,
        padding: const EdgeInsets.symmetric(vertical: 18),
        side: const BorderSide(color: Colors.black12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}