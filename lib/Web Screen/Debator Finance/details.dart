// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'debatorcontroller.dart';
import 'model.dart';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasepage.dart';



class Debatordetails extends StatefulWidget {
  final String id;
  final String name;

  const Debatordetails({super.key, required this.id, required this.name});

  @override
  State<Debatordetails> createState() => _DebatordetailsState();
}

class _DebatordetailsState extends State<Debatordetails> {
  final controller = Get.find<DebatorController>();
  final ScrollController _scrollController = ScrollController();

  // --- ERP THEME CONSTANTS ---
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  // --- TRANSACTION COLORS ---
  static const Color colCredit = Color(0xFFEF4444); // Red
  static const Color colDebit = Color(0xFF10B981); // Green
  static const Color colAdvGiven = Color(0xFFF59E0B); // Amber
  static const Color colAdvRecv = Color(0xFF06B6D4); // Cyan
  static const Color colPrevious = Colors.orange; // NEW
  static const Color colLoanPay = Colors.purple; // NEW

  @override
  void initState() {
    super.initState();
    controller.clearTransactionState();
    controller.loadDebtorTransactions(widget.id);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      controller.loadDebtorTransactions(widget.id, loadMore: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtor = controller.bodies.firstWhereOrNull((e) => e.id == widget.id);
    if (debtor == null) {
      return const Scaffold(body: Center(child: Text("Debtor Not Found")));
    }

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: _buildAppBar(debtor),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: darkSlate,
        onPressed: () => _showAddTransactionDialog(debtor),
        icon: const Icon(Icons.add_card, color: Colors.white),
        label: const Text("New Entry", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. UPDATED LIVE BALANCE CARDS (3-Card Layout)
            _buildLiveBalanceSection(),

            const SizedBox(height: 24),

            // 2. FILTERS
            _buildFilterBar(),

            const SizedBox(height: 16),

            // 3. TABLE
            _buildTableSection(debtor),

            // 4. LOADER
            Obx(() {
              if (controller.isTxLoading.value &&
                  controller.currentTransactions.isNotEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return const SizedBox(height: 80);
            }),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(DebtorModel debtor) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: darkSlate),
        onPressed: () => Get.back(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.name,
            style: const TextStyle(
              color: darkSlate,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Text(
            "Financial Ledger",
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            FontAwesomeIcons.bagShopping,
            size: 18,
            color: darkSlate,
          ),
          tooltip: "Purchases",
          onPressed:
              () => Get.to(
                () => DebtorPurchasePage(
                  debtorId: widget.id,
                  debtorName: widget.name,
                ),
              ),
        ),
        _actionTextBtn(
          Icons.edit,
          "Profile",
          activeAccent,
          () => _showEditProfileDialog(debtor),
        ),
        _actionTextBtn(
          FontAwesomeIcons.filePdf,
          "Statement",
          Colors.redAccent,
          () => _downloadPDF(),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _actionTextBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // --- UPDATED LIVE BALANCE (3 CARDS) ---
  Widget _buildLiveBalanceSection() {
    return StreamBuilder<Map<String, double>>(
      stream: controller.getDebtorBreakdown(widget.id),
      builder: (context, snap) {
        final data = snap.data ?? {'loan': 0.0, 'running': 0.0, 'total': 0.0};
        double loan = data['loan']!;
        double running = data['running']!;
        double total = data['total']!;

        return Column(
          children: [
            // TOTAL CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1F2937), const Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
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
                      Text(
                        "TOTAL OUTSTANDING (NET)",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tk ${total.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.sackDollar,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // BREAKDOWN ROW
            Row(
              children: [
                // PREVIOUS LOAN CARD
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              FontAwesomeIcons.clockRotateLeft,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "PREVIOUS LOAN",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tk ${loan.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // RUNNING BILLS CARD
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeAccent.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              FontAwesomeIcons.receipt,
                              size: 14,
                              color: activeAccent,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "RUNNING BILLS",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tk ${running.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: activeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18, color: textMuted),
          const SizedBox(width: 12),
          const Text(
            "Filter By:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Obx(() {
            final hasFilter = controller.selectedDateRange.value != null;
            return ActionChip(
              label: Text(
                hasFilter
                    ? "${DateFormat('dd MMM').format(controller.selectedDateRange.value!.start)} - ${DateFormat('dd MMM').format(controller.selectedDateRange.value!.end)}"
                    : "Date Range",
              ),
              avatar:
                  hasFilter
                      ? const Icon(Icons.close, size: 14)
                      : const Icon(Icons.calendar_today, size: 14),
              backgroundColor:
                  hasFilter ? activeAccent.withOpacity(0.1) : bgGrey,
              onPressed:
                  () =>
                      hasFilter
                          ? controller.setDateFilter(null, widget.id)
                          : _pickDateRange(),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) controller.setDateFilter(picked, widget.id);
  }

  Widget _buildTableSection(DebtorModel debtor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _tableHeader(),
          Obx(() {
            if (controller.isTxLoading.value &&
                controller.currentTransactions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              );
            }
            if (controller.currentTransactions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  "No transactions found.",
                  style: TextStyle(color: textMuted),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.currentTransactions.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder:
                  (context, index) =>
                      _tableRow(controller.currentTransactions[index], debtor),
            );
          }),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              "DATE",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "TYPE",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "DETAILS / NOTE",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "AMOUNT",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              "ACTION",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(TransactionModel tx, DebtorModel debtor) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (tx.type) {
      case 'credit':
        typeColor = colCredit;
        typeIcon = FontAwesomeIcons.fileInvoiceDollar;
        typeLabel = "BILL / SALE";
        break;
      case 'debit':
        typeColor = colDebit;
        typeIcon = FontAwesomeIcons.handHoldingDollar;
        typeLabel = "PAYMENT";
        break;
      case 'advance_given':
        typeColor = colAdvGiven;
        typeIcon = FontAwesomeIcons.arrowRightFromBracket;
        typeLabel = "ADV GIVEN";
        break;
      case 'advance_received':
        typeColor = colAdvRecv;
        typeIcon = FontAwesomeIcons.arrowRightToBracket;
        typeLabel = "ADV RECV";
        break;
      case 'previous_due':
        typeColor = colPrevious;
        typeIcon = FontAwesomeIcons.clockRotateLeft;
        typeLabel = "OLD DEBT";
        break;
      case 'loan_payment':
        typeColor = colLoanPay;
        typeIcon = FontAwesomeIcons.moneyBillWave;
        typeLabel = "LOAN COLLECT";
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.circle;
        typeLabel = tx.type;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat("dd MMM yy").format(tx.date),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(typeIcon, size: 12, color: typeColor),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tx.paymentMethod != null)
                  Text(
                    formatPaymentMethod(tx.paymentMethod!),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: darkSlate,
                    ),
                  ),
                Text(
                  tx.note.isEmpty ? "-" : tx.note,
                  style: const TextStyle(fontSize: 11, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Tk ${tx.amount.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconBtn(
                  Icons.edit,
                  activeAccent,
                  () => _showEditTransactionDialog(tx, debtor),
                ),
                const SizedBox(width: 8),
                _iconBtn(
                  Icons.delete,
                  Colors.red.shade300,
                  () => _confirmDelete(tx),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // --- UPDATED DIALOG (WITH NEW TYPES) ---
  void _showAddTransactionDialog(DebtorModel debtor) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final RxString selectedType = 'credit'.obs;
    final Rx<DateTime> selectedDate = DateTime.now().obs;
    final Rx<Map<String, dynamic>?> selectedPayment = Rx<Map<String, dynamic>?>(
      debtor.payments.isNotEmpty ? debtor.payments.first : null,
    );

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader("New Transaction Entry"),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Obx(
                  () => Column(
                    children: [
                      _buildField(
                        amountC,
                        "Amount (Tk)",
                        Icons.attach_money,
                        isNum: true,
                      ),
                      const SizedBox(height: 12),
                      _buildField(noteC, "Note / Description", Icons.note),
                      const SizedBox(height: 12),

                      // UPDATED DROPDOWN
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: bgGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType.value,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'credit',
                                child: Text("🧾  New Sale/Bill (Running Due)"),
                              ),
                              DropdownMenuItem(
                                value: 'debit',
                                child: Text("💵  Receive Payment (Running)"),
                              ),
                              DropdownMenuItem(
                                value: 'div1',
                                enabled: false,
                                child: Divider(),
                              ),
                              DropdownMenuItem(
                                value: 'previous_due',
                                child: Text("🏦  Add Previous/Old Debt"),
                              ),
                              DropdownMenuItem(
                                value: 'loan_payment',
                                child: Text("💰  Collect Old Debt (Cash In)"),
                              ),
                              DropdownMenuItem(
                                value: 'div2',
                                enabled: false,
                                child: Divider(),
                              ),
                              DropdownMenuItem(
                                value: 'advance_received',
                                child: Text("⬅️  Receive Advance"),
                              ),
                              DropdownMenuItem(
                                value: 'advance_given',
                                child: Text("➡️  Give Advance"),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null && !v.contains('div')) {
                                selectedType.value = v;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if ([
                        'debit',
                        'loan_payment',
                        'advance_received',
                      ].contains(selectedType.value))
                        _buildPaymentDropdown(debtor.payments, selectedPayment),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkSlate,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () async {
                              if (amountC.text.isEmpty) return;
                              await controller.addTransaction(
                                debtorId: debtor.id,
                                amount: double.tryParse(amountC.text) ?? 0,
                                note: noteC.text,
                                type: selectedType.value,
                                date: selectedDate.value,
                                selectedPaymentMethod: selectedPayment.value,
                              );
                            },
                            child: const Text(
                              "Save Entry",
                              style: TextStyle(color: Colors.white),
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
    );
  }

  // --- RESTORED: EDIT TRANSACTION DIALOG ---
  void _showEditTransactionDialog(TransactionModel tx, DebtorModel debtor) {
    final amountC = TextEditingController(text: tx.amount.toString());
    final noteC = TextEditingController(text: tx.note);
    final RxString selectedType = tx.type.obs;
    final Rx<DateTime> selectedDate = tx.date.obs;
    final Rx<Map<String, dynamic>?> selectedPayment = Rx<Map<String, dynamic>?>(
      null,
    );

    if (tx.paymentMethod != null) {
      selectedPayment.value = debtor.payments.firstWhereOrNull(
        (p) => p['number'] == tx.paymentMethod?['number'],
      );
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader("Edit Transaction"),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Obx(
                  () => Column(
                    children: [
                      _buildField(amountC, "Amount", Icons.money, isNum: true),
                      const SizedBox(height: 12),
                      _buildField(noteC, "Note", Icons.edit),
                      const SizedBox(height: 12),
                      _buildDropdown<String>(
                        value: selectedType.value,
                        items: const [
                          DropdownMenuItem(
                            value: 'credit',
                            child: Text("CREDIT SALE"),
                          ),
                          DropdownMenuItem(
                            value: 'debit',
                            child: Text("PAYMENT"),
                          ),
                          DropdownMenuItem(
                            value: 'previous_due',
                            child: Text("OLD DEBT"),
                          ),
                          DropdownMenuItem(
                            value: 'loan_payment',
                            child: Text("LOAN PAY"),
                          ),
                          DropdownMenuItem(
                            value: 'advance_received',
                            child: Text("ADV RECV"),
                          ),
                          DropdownMenuItem(
                            value: 'advance_given',
                            child: Text("ADV GIVEN"),
                          ),
                        ],
                        onChanged: (v) => selectedType.value = v!,
                      ),
                      const SizedBox(height: 12),
                      if ([
                        'debit',
                        'loan_payment',
                        'advance_received',
                      ].contains(selectedType.value))
                        _buildPaymentDropdown(debtor.payments, selectedPayment),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeAccent,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () async {
                          await controller.editTransaction(
                            debtorId: debtor.id,
                            transactionId: tx.id,
                            oldAmount: tx.amount,
                            newAmount: double.tryParse(amountC.text) ?? 0,
                            oldType: tx.type,
                            newType: selectedType.value,
                            note: noteC.text,
                            date: selectedDate.value,
                            paymentMethod: selectedPayment.value,
                          );
                        },
                        child: const Text(
                          "Update",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(TransactionModel tx) {
    Get.defaultDialog(
      title: "Confirm Delete",
      middleText:
          "Are you sure you want to delete this transaction of Tk ${tx.amount}? This will revert the balance.",
      textConfirm: "Delete Forever",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back();
        await controller.deleteTransaction(widget.id, tx.id);
      },
    );
  }

  // --- RESTORED: EDIT PROFILE DIALOG ---
  void _showEditProfileDialog(DebtorModel debtor) {
    final nameC = TextEditingController(text: debtor.name);
    final phoneC = TextEditingController(text: debtor.phone);
    final nidC = TextEditingController(text: debtor.nid);
    final addressC = TextEditingController(text: debtor.address);
    final desC = TextEditingController(text: debtor.des);

    Get.defaultDialog(
      title: "Edit Profile",
      content: Column(
        children: [
          _buildField(nameC, "Name", Icons.person),
          const SizedBox(height: 8),
          _buildField(phoneC, "Phone", Icons.phone),
          const SizedBox(height: 8),
          _buildField(nidC, "NID", Icons.badge),
          const SizedBox(height: 8),
          _buildField(addressC, "Address", Icons.home),
          const SizedBox(height: 8),
          _buildField(desC, "Description", Icons.description),
        ],
      ),
      textConfirm: "Save",
      onConfirm: () async {
        await controller.editDebtor(
          id: debtor.id,
          oldName: debtor.name,
          newName: nameC.text,
          des: desC.text,
          nid: nidC.text,
          phone: phoneC.text,
          address: addressC.text,
          payments: debtor.payments,
        );
      },
    );
  }

  // --- PDF DOWNLOAD ---
  Future<void> _downloadPDF() async {
    final snap =
        await controller.db
            .collection("debatorbody")
            .doc(widget.id)
            .collection("transactions")
            .orderBy("date")
            .get();
    List<Map<String, dynamic>> data =
        snap.docs.map((d) {
          final map = d.data();
          return {
            "date":
                (map["date"] is Timestamp)
                    ? (map["date"] as Timestamp).toDate()
                    : map["date"],
            "type": map["type"],
            "amount": (map["amount"] as num).toDouble(),
            "note": map["note"] ?? "",
            "paymentMethod": map["paymentMethod"],
          };
        }).toList();

    final List<int> bytes = await controller.generatePDF(widget.name, data);
    final Uint8List uint8list = Uint8List.fromList(bytes);
    final JSUint8Array jsBytes = uint8list.toJS;
    final blob = web.Blob(
      [jsBytes].toJS as JSArray<web.BlobPart>,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = "${widget.name}_Statement.pdf";
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  // --- HELPERS ---
  Widget _dialogHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool isNum = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 16, color: textMuted),
        hintText: hint,
        filled: true,
        fillColor: bgGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildPaymentDropdown(
    List<Map<String, dynamic>> payments,
    Rx<Map<String, dynamic>?> selected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: payments.contains(selected.value) ? selected.value : null,
          hint: const Text("Select Payment Method"),
          isExpanded: true,
          items:
              payments
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p['type'].toString().toUpperCase()),
                    ),
                  )
                  .toList(),
          onChanged: (v) => selected.value = v,
        ),
      ),
    );
  }
}

String formatPaymentMethod(Map<String, dynamic> pm) {
  String type = pm['type']?.toString().toUpperCase() ?? "";
  String num = pm['number'] ?? "";
  return num.isEmpty ? type : "$type ($num)";
}
