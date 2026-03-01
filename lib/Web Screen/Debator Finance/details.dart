// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, use_build_context_synchronously

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'debatorcontroller.dart';
import 'model.dart';
import 'dart:js_interop';
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

  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _filterType = 'All'.obs;

  // --- COLORS ---
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    controller.clearTransactionState();
    // Load exactly Page 1 from server
    controller.loadTxPage(widget.id, 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Filters within the CURRENT fetched page (20 items max)
  List<TransactionModel> get _processedTransactions {
    List<TransactionModel> list = controller.currentTransactions.toList();

    if (_filterType.value == 'Sales') {
      list =
          list
              .where(
                (t) =>
                    t.type == 'credit' ||
                    t.type == 'advance_given' ||
                    t.type == 'previous_due',
              )
              .toList();
    } else if (_filterType.value == 'Payments') {
      list =
          list
              .where(
                (t) =>
                    t.type == 'debit' ||
                    t.type == 'advance_received' ||
                    t.type == 'loan_payment',
              )
              .toList();
    }

    if (_searchCtrl.text.isNotEmpty) {
      String q = _searchCtrl.text.toLowerCase();
      list =
          list.where((t) {
            String note = (t.note).toLowerCase();
            String method = "";
            if (t.paymentMethod != null) {
              method = t.paymentMethod.toString().toLowerCase();
            }
            return note.contains(q) || method.contains(q);
          }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final debtor =
        controller.bodies.firstWhereOrNull((e) => e.id == widget.id) ??
        controller.filteredBodies.firstWhereOrNull((e) => e.id == widget.id);

    if (debtor == null &&
        controller.bodies.isEmpty &&
        controller.filteredBodies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (debtor == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name, style: const TextStyle(color: darkSlate)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: darkSlate),
            onPressed: () {
              if (mounted) Navigator.pop(context);
            },
          ),
        ),
        body: const Center(
          child: Text(
            "Debtor Not Found. Please refresh the previous page.",
            style: TextStyle(color: textMuted, fontSize: 16),
          ),
        ),
      );
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveBalanceSection(),
            const SizedBox(height: 24),
            _buildAdvancedToolbar(),
            const SizedBox(height: 16),
            _buildTableSection(debtor),
            const SizedBox(height: 16),
            _buildPaginationFooter(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // APP BAR & HEADER
  // ==========================================
  AppBar _buildAppBar(DebtorModel debtor) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: darkSlate),
        onPressed: () {
          if (mounted) Navigator.pop(context);
        },
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
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
            Row(
              children: [
                Expanded(
                  child: _balanceCard(
                    FontAwesomeIcons.clockRotateLeft,
                    "PREVIOUS LOAN",
                    loan,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _balanceCard(
                    FontAwesomeIcons.receipt,
                    "RUNNING BILLS",
                    running,
                    activeAccent,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _balanceCard(IconData icon, String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Tk ${amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: "Search Invoice, Note, Bank Acc...",
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: Colors.grey,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Obx(
              () => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType.value,
                    icon: const Icon(
                      Icons.filter_list,
                      size: 18,
                      color: Colors.grey,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text("All Transactions"),
                      ),
                      DropdownMenuItem(
                        value: 'Sales',
                        child: Text("Sales / Bills Only"),
                      ),
                      DropdownMenuItem(
                        value: 'Payments',
                        child: Text("Payments Only"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _filterType.value = v;
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DATA TABLE
  // ==========================================
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
            if (controller.isTxLoading.value) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              );
            }

            final txList = _processedTransactions;

            if (txList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  "No transactions found matching criteria.",
                  style: TextStyle(color: textMuted),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txList.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (context, index) => _tableRow(txList[index], debtor),
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
          Expanded(flex: 2, child: Text("DATE", style: _headStyle)),
          Expanded(flex: 2, child: Text("TYPE", style: _headStyle)),
          Expanded(flex: 3, child: Text("DETAILS / METHOD", style: _headStyle)),
          Expanded(
            flex: 2,
            child: Text(
              "AMOUNT",
              textAlign: TextAlign.right,
              style: _headStyle,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              "ACTION",
              textAlign: TextAlign.center,
              style: _headStyle,
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _headStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 11,
    color: textMuted,
  );

  Widget _tableRow(TransactionModel tx, DebtorModel debtor) {
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.circle;
    String typeLabel = tx.type;

    if (tx.type == 'credit') {
      typeColor = const Color(0xFFEF4444);
      typeIcon = FontAwesomeIcons.fileInvoiceDollar;
      typeLabel = "BILL / SALE";
    } else if (tx.type == 'debit') {
      typeColor = const Color(0xFF10B981);
      typeIcon = FontAwesomeIcons.handHoldingDollar;
      typeLabel = "PAYMENT";
    } else if (tx.type == 'advance_given') {
      typeColor = const Color(0xFFF59E0B);
      typeIcon = FontAwesomeIcons.arrowRightFromBracket;
      typeLabel = "ADV GIVEN";
    } else if (tx.type == 'advance_received') {
      typeColor = const Color(0xFF06B6D4);
      typeIcon = FontAwesomeIcons.arrowRightToBracket;
      typeLabel = "ADV RECV";
    } else if (tx.type == 'previous_due') {
      typeColor = Colors.orange;
      typeIcon = FontAwesomeIcons.clockRotateLeft;
      typeLabel = "OLD DEBT";
    } else if (tx.type == 'loan_payment') {
      typeColor = Colors.purple;
      typeIcon = FontAwesomeIcons.moneyBillWave;
      typeLabel = "LOAN COLLECT";
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
                    formatDynamicPayment(tx.paymentMethod!),
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

  Widget _buildPaginationFooter() {
    return Obx(() {
      if (controller.currentTxPage.value == 1 && !controller.hasMoreTx.value) {
        return const SizedBox.shrink(); // Hide footer if only 1 page exist
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed:
                controller.currentTxPage.value > 1
                    ? () => controller.prevTxPage(widget.id)
                    : null,
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const Text("Previous"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: darkSlate,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: activeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Page ${controller.currentTxPage.value}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: activeAccent,
              ),
            ),
          ),
          const SizedBox(width: 15),
          ElevatedButton.icon(
            onPressed:
                controller.hasMoreTx.value
                    ? () => controller.nextTxPage(widget.id)
                    : null,
            icon: const Icon(Icons.chevron_right, size: 16),
            label: const Text("Next"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: darkSlate,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ],
      );
    });
  }

  // ==========================================
  // DIALOGS
  // ==========================================

  void _showAddTransactionDialog(DebtorModel debtor) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final RxString selectedType = 'credit'.obs;
    final Rx<DateTime> selectedDate = DateTime.now().obs;

    final RxString payMethodType = 'cash'.obs;
    final bankNameC = TextEditingController();
    final accountNoC = TextEditingController();
    final mobileNoC = TextEditingController();

    // Added loading state
    final RxBool isSubmitting = false.obs;

    Get.dialog(
      Builder(
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogHeader("New Transaction Entry"),
                  Flexible(
                    child: SingleChildScrollView(
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
                            _buildField(
                              noteC,
                              "Note / Description",
                              Icons.note,
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown<String>(
                              value: selectedType.value,
                              items: const [
                                DropdownMenuItem(
                                  value: 'credit',
                                  child: Text(
                                    "🧾  New Sale/Bill (Running Due)",
                                  ),
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
                            if ([
                              'debit',
                              'loan_payment',
                              'advance_received',
                            ].contains(selectedType.value)) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              _buildDynamicPaymentSection(
                                payMethodType,
                                bankNameC,
                                accountNoC,
                                mobileNoC,
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed:
                                      isSubmitting.value
                                          ? null
                                          : () {
                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                          },
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
                                  onPressed:
                                      isSubmitting.value
                                          ? null
                                          : () async {
                                            if (amountC.text.isEmpty) return;

                                            isSubmitting.value =
                                                true; // Start Loading

                                            try {
                                              Map<String, dynamic> pm = {
                                                'type': 'cash',
                                              };
                                              if ([
                                                'debit',
                                                'loan_payment',
                                                'advance_received',
                                              ].contains(selectedType.value)) {
                                                if (payMethodType.value ==
                                                    'bank') {
                                                  pm = {
                                                    'type': 'bank',
                                                    'bankName':
                                                        bankNameC.text.trim(),
                                                    'accountNo':
                                                        accountNoC.text.trim(),
                                                  };
                                                } else if ([
                                                  'bkash',
                                                  'nagad',
                                                  'rocket',
                                                ].contains(
                                                  payMethodType.value,
                                                )) {
                                                  pm = {
                                                    'type': payMethodType.value,
                                                    'number':
                                                        mobileNoC.text.trim(),
                                                  };
                                                }
                                              }

                                              await controller.addTransaction(
                                                debtorId: debtor.id,
                                                amount:
                                                    double.tryParse(
                                                      amountC.text,
                                                    ) ??
                                                    0,
                                                note: noteC.text,
                                                type: selectedType.value,
                                                date: selectedDate.value,
                                                paymentMethodData: pm,
                                              );

                                              if (dialogContext.mounted) {
                                                Navigator.pop(
                                                  dialogContext,
                                                ); // Close Dialog safely
                                              }
                                            } catch (e) {
                                              Get.snackbar(
                                                "Error",
                                                "Failed to add transaction",
                                              );
                                            } finally {
                                              isSubmitting.value =
                                                  false; // Stop Loading
                                            }
                                          },
                                  child:
                                      isSubmitting.value
                                          ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text(
                                            "Save Entry",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierDismissible:
          false, // Prevent closing by tapping outside while loading
    );
  }

  void _showEditTransactionDialog(TransactionModel tx, DebtorModel debtor) {
    final amountC = TextEditingController(text: tx.amount.toString());
    final noteC = TextEditingController(text: tx.note);
    final RxString selectedType = tx.type.obs;
    final Rx<DateTime> selectedDate = tx.date.obs;

    final map = tx.paymentMethod ?? {'type': 'cash'};
    final RxString payMethodType =
        (map['type'] ?? 'cash').toString().toLowerCase().obs;
    final bankNameC = TextEditingController(text: map['bankName'] ?? '');
    final accountNoC = TextEditingController(text: map['accountNo'] ?? '');
    final mobileNoC = TextEditingController(text: map['number'] ?? '');

    // Added loading state
    final RxBool isSubmitting = false.obs;

    Get.dialog(
      Builder(
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogHeader("Edit Transaction"),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Obx(
                        () => Column(
                          children: [
                            _buildField(
                              amountC,
                              "Amount",
                              Icons.money,
                              isNum: true,
                            ),
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
                            if ([
                              'debit',
                              'loan_payment',
                              'advance_received',
                            ].contains(selectedType.value)) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              _buildDynamicPaymentSection(
                                payMethodType,
                                bankNameC,
                                accountNoC,
                                mobileNoC,
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed:
                                      isSubmitting.value
                                          ? null
                                          : () {
                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                          },
                                  child: const Text("Cancel"),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: activeAccent,
                                    minimumSize: const Size(120, 50),
                                  ),
                                  onPressed:
                                      isSubmitting.value
                                          ? null
                                          : () async {
                                            isSubmitting.value =
                                                true; // Start Loading
                                            try {
                                              Map<String, dynamic> pm = {
                                                'type': 'cash',
                                              };
                                              if ([
                                                'debit',
                                                'loan_payment',
                                                'advance_received',
                                              ].contains(selectedType.value)) {
                                                if (payMethodType.value ==
                                                    'bank') {
                                                  pm = {
                                                    'type': 'bank',
                                                    'bankName':
                                                        bankNameC.text.trim(),
                                                    'accountNo':
                                                        accountNoC.text.trim(),
                                                  };
                                                } else if ([
                                                  'bkash',
                                                  'nagad',
                                                  'rocket',
                                                ].contains(
                                                  payMethodType.value,
                                                )) {
                                                  pm = {
                                                    'type': payMethodType.value,
                                                    'number':
                                                        mobileNoC.text.trim(),
                                                  };
                                                }
                                              }

                                              await controller.editTransaction(
                                                debtorId: debtor.id,
                                                transactionId: tx.id,
                                                oldAmount: tx.amount,
                                                newAmount:
                                                    double.tryParse(
                                                      amountC.text,
                                                    ) ??
                                                    0,
                                                oldType: tx.type,
                                                newType: selectedType.value,
                                                note: noteC.text,
                                                date: selectedDate.value,
                                                paymentMethod: pm,
                                              );

                                              if (dialogContext.mounted) {
                                                Navigator.pop(
                                                  dialogContext,
                                                ); // Close Dialog safely
                                              }
                                            } catch (e) {
                                              Get.snackbar(
                                                "Error",
                                                "Failed to update transaction",
                                              );
                                            } finally {
                                              isSubmitting.value =
                                                  false; // Stop Loading
                                            }
                                          },
                                  child:
                                      isSubmitting.value
                                          ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text(
                                            "Update",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  void _showEditProfileDialog(DebtorModel debtor) {
    final nameC = TextEditingController(text: debtor.name);
    final phoneC = TextEditingController(text: debtor.phone);
    final nidC = TextEditingController(text: debtor.nid);
    final addressC = TextEditingController(text: debtor.address);
    final desC = TextEditingController(text: debtor.des);

    final RxBool isSubmitting = false.obs;

    Get.dialog(
      Builder(
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              "Edit Profile",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
            ),
            actions: [
              Obx(
                () => TextButton(
                  onPressed:
                      isSubmitting.value
                          ? null
                          : () {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                  child: const Text("Cancel"),
                ),
              ),
              Obx(
                () => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeAccent,
                  ),
                  onPressed:
                      isSubmitting.value
                          ? null
                          : () async {
                            isSubmitting.value = true;
                            try {
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
                              if (dialogContext.mounted) {
                                Navigator.pop(
                                  dialogContext,
                                ); // Close dialog safely
                              }
                            } catch (e) {
                              Get.snackbar("Error", "Failed to update profile");
                            } finally {
                              isSubmitting.value = false;
                            }
                          },
                  child:
                      isSubmitting.value
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Save",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  void _confirmDelete(TransactionModel tx) {
    final RxBool isDeleting = false.obs;

    Get.dialog(
      Builder(
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              "Confirm Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Are you sure you want to delete this transaction of Tk ${tx.amount}?",
            ),
            actions: [
              Obx(
                () => TextButton(
                  onPressed:
                      isDeleting.value
                          ? null
                          : () {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                  child: const Text("Cancel"),
                ),
              ),
              Obx(
                () => ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed:
                      isDeleting.value
                          ? null
                          : () async {
                            isDeleting.value = true;
                            try {
                              await controller.deleteTransaction(
                                widget.id,
                                tx.id,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(
                                  dialogContext,
                                ); // Close dialog safely
                              }
                            } catch (e) {
                              Get.snackbar(
                                "Error",
                                "Failed to delete transaction",
                              );
                            } finally {
                              isDeleting.value = false;
                            }
                          },
                  child:
                      isDeleting.value
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Delete Forever",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }

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

  // ==========================================
  // HELPERS
  // ==========================================

  Widget _buildDynamicPaymentSection(
    RxString methodType,
    TextEditingController bankC,
    TextEditingController accC,
    TextEditingController mobC,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
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
                      Icon(
                        Icons.account_balance,
                        size: 16,
                        color: Colors.indigo,
                      ),
                      SizedBox(width: 8),
                      Text("Bank Transfer"),
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
                      Icon(
                        Icons.mobile_friendly,
                        size: 16,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Text("Nagad"),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'rocket',
                  child: Row(
                    children: [
                      Icon(
                        Icons.mobile_friendly,
                        size: 16,
                        color: Colors.purple,
                      ),
                      SizedBox(width: 8),
                      Text("Rocket"),
                    ],
                  ),
                ),
              ],
              onChanged: (v) => methodType.value = v!,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (methodType.value == 'bank') ...[
          _buildField(bankC, "Bank Name (e.g. Islami Bank)", Icons.business),
          const SizedBox(height: 8),
          _buildField(accC, "Account Number", Icons.numbers),
        ] else if (['bkash', 'nagad', 'rocket'].contains(methodType.value)) ...[
          _buildField(
            mobC,
            "${methodType.value.capitalizeFirst} Number",
            Icons.phone_android,
            isNum: true,
          ),
        ],
      ],
    );
  }

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
}

String formatDynamicPayment(Map<String, dynamic> pm) {
  String type = (pm['type'] ?? 'Cash').toString().toUpperCase();
  if (type == 'BANK') {
    return "BANK: ${pm['bankName'] ?? ''}\nACC: ${pm['accountNo'] ?? ''}";
  } else if (['BKASH', 'NAGAD', 'ROCKET'].contains(type)) {
    return "$type: ${pm['number'] ?? ''}";
  }
  return type;
}