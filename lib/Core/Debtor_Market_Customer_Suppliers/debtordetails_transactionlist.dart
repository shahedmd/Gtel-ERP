import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../Web Screen/Debator Finance/Debtor Purchase/purchasepage.dart';
import 'gteldebtorcontroller.dart';
import '../../Web Screen/Sales/controller.dart';
import 'debtordartmodel.dart';

// --- THEME COLORS ---
const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF2563EB);
const Color bgGrey = Color(0xFFF8FAFC);
const Color textMuted = Color(0xFF64748B);
const Color debitColor = Color(0xFFDC2626); // Red
const Color creditColor = Color(0xFF16A34A); // Green

class TableScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

// --- ACCOUNTING WRAPPER ---
class DisplayTx {
  final String id;
  final double debitAmount;
  final double creditAmount;
  final String note;
  final String type;
  final DateTime date;
  final Map<String, dynamic>? paymentMethod;
  final TransactionModel originalTx;
  final TransactionModel? pairedTx;

  DisplayTx({
    required this.id,
    required this.debitAmount,
    required this.creditAmount,
    required this.note,
    required this.type,
    required this.date,
    this.paymentMethod,
    required this.originalTx,
    this.pairedTx,
  });
}

// ============================================================================
// STATE CONTROLLERS FOR PAGE (100% GetX)
// ============================================================================
class DebtorDetailsController extends GetxController {
  final String debtorId;
  final DebatorController mainController = Get.find<DebatorController>();

  final TextEditingController searchCtrl = TextEditingController();
  final RxString filterType = 'All'.obs;

  DebtorDetailsController(this.debtorId);

  @override
  void onInit() {
    super.onInit();
    mainController.clearTransactionState();
    mainController.loadTxPage(debtorId, 1);

    searchCtrl.addListener(() {
      update(['table_section']);
    });
  }

  @override
  void onClose() {
    searchCtrl.dispose();
    super.onClose();
  }

  void updateFilter(String val) {
    filterType.value = val;
    update(['table_section']);
  }

  List<DisplayTx> get processedTransactions {
    List<TransactionModel> rawList =
        mainController.currentTransactions.toList();
    List<DisplayTx> mergedList = [];
    Set<String> skipIds = {};

    for (var tx in rawList) {
      if (skipIds.contains(tx.id)) continue;

      if (tx.type == 'credit' || tx.type == 'debit') {
        String creditId =
            tx.type == 'credit' ? tx.id : tx.id.replaceAll('_pay', '');
        String payId = '${creditId}_pay';

        var creditTx = rawList.firstWhereOrNull((t) => t.id == creditId);
        var payTx = rawList.firstWhereOrNull((t) => t.id == payId);

        if (creditTx != null &&
            payTx != null &&
            creditTx.amount == payTx.amount) {
          mergedList.add(
            DisplayTx(
              id: creditTx.id,
              debitAmount: creditTx.amount,
              creditAmount: payTx.amount,
              note: creditTx.note,
              type: 'paid_sale',
              date: creditTx.date,
              paymentMethod: payTx.paymentMethod,
              originalTx: creditTx,
              pairedTx: payTx,
            ),
          );
          skipIds.add(creditId);
          skipIds.add(payId);
          continue;
        }
      }

      bool isDebitEntry = [
        'credit',
        'previous_due',
        'advance_given',
      ].contains(tx.type);

      mergedList.add(
        DisplayTx(
          id: tx.id,
          debitAmount: isDebitEntry ? tx.amount : 0.0,
          creditAmount: !isDebitEntry ? tx.amount : 0.0,
          note: tx.note,
          type: tx.type,
          date: tx.date,
          paymentMethod: tx.paymentMethod,
          originalTx: tx,
        ),
      );
    }

    if (filterType.value == 'Debits') {
      mergedList = mergedList.where((t) => t.debitAmount > 0).toList();
    } else if (filterType.value == 'Credits') {
      mergedList = mergedList.where((t) => t.creditAmount > 0).toList();
    }

    if (searchCtrl.text.isNotEmpty) {
      String q = searchCtrl.text.toLowerCase();
      mergedList =
          mergedList.where((t) {
            return t.note.toLowerCase().contains(q) ||
                (t.paymentMethod?.toString() ?? "").toLowerCase().contains(q);
          }).toList();
    }

    return mergedList;
  }

  void printInvoice(String invoiceId) async {
    BuildContext? dialogContext;
    Get.dialog(
      Builder(
        builder: (ctx) {
          dialogContext = ctx;
          return const Center(
            child: CircularProgressIndicator(color: activeAccent),
          );
        },
      ),
      barrierDismissible: false,
    );
    try {
      if (!Get.isRegistered<DailySalesController>()) {
        Get.put(DailySalesController());
      }
      await Get.find<DailySalesController>().reprintInvoice(invoiceId);
    } catch (e) {
      Get.snackbar("Error", "Could not load invoice: $e");
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }
  }
}

// ============================================================================
// MAIN PAGE (Stateless)
// ============================================================================
class Debatordetails extends StatelessWidget {
  final String id;
  final String name;

  Debatordetails({super.key, required this.id, required this.name});

  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    final pageCtrl = Get.put(DebtorDetailsController(id), tag: id);
    final mainController = pageCtrl.mainController;

    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return Obx(() {
      final debtor =
          mainController.bodies.firstWhereOrNull((e) => e.id == id) ??
          mainController.filteredBodies.firstWhereOrNull((e) => e.id == id);

      if (debtor == null &&
          mainController.bodies.isEmpty &&
          mainController.filteredBodies.isEmpty) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (debtor == null) {
        return Scaffold(
          appBar: AppBar(
            title: Text(name, style: const TextStyle(color: darkSlate)),
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: darkSlate),
              onPressed: () => Get.back(),
            ),
          ),
          body: const Center(
            child: Text(
              "Debtor Not Found. Please refresh.",
              style: TextStyle(color: textMuted),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: bgGrey,
        appBar: _buildAppBar(context, debtor, isMobile, pageCtrl),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: darkSlate,
          onPressed: () => _openAddTransactionDialog(debtor, mainController),
          icon: const Icon(Icons.add_card, color: Colors.white),
          label: const Text(
            "New Entry",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveBalanceSection(mainController, isMobile),
              const SizedBox(height: 24),
              _buildAdvancedToolbar(pageCtrl, isMobile),
              const SizedBox(height: 16),
              _buildTableSection(debtor, mainController, pageCtrl, isMobile),
              const SizedBox(height: 16),
              _buildPaginationFooter(mainController),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    });
  }

  // --- APP BAR ---
  AppBar _buildAppBar(
    BuildContext context,
    DebtorModel debtor,
    bool isMobile,
    DebtorDetailsController pageCtrl,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: darkSlate),
        onPressed: () {
          Get.delete<DebtorDetailsController>(tag: id);
          Get.back();
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: darkSlate,
              fontWeight: FontWeight.w800,
              fontSize: isMobile ? 16 : 18,
            ),
          ),
          const Text(
            "Financial Ledger",
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      actions: [
        if (isMobile)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: darkSlate),
            onSelected: (val) {
              if (val == 'purchases') {
                Get.to(
                  () => DebtorPurchasePage(debtorId: id, debtorName: name),
                );
              }
              if (val == 'profile') {
                _openEditProfileDialog(debtor, pageCtrl.mainController);
              }
              if (val == 'pdf') {
                _openPdfDownloadDialog(id, name, pageCtrl.mainController);
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: 'purchases',
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.bagShopping,
                          size: 16,
                          color: darkSlate,
                        ),
                        SizedBox(width: 10),
                        Text("Purchases", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: activeAccent),
                        SizedBox(width: 10),
                        Text("Profile", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.filePdf,
                          size: 16,
                          color: debitColor,
                        ),
                        SizedBox(width: 10),
                        Text("Statement", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
          )
        else ...[
          IconButton(
            icon: const Icon(
              FontAwesomeIcons.bagShopping,
              size: 18,
              color: darkSlate,
            ),
            tooltip: "Purchases",
            onPressed:
                () => Get.to(
                  () => DebtorPurchasePage(debtorId: id, debtorName: name),
                ),
          ),
          TextButton.icon(
            onPressed:
                () => _openEditProfileDialog(debtor, pageCtrl.mainController),
            icon: const Icon(Icons.edit, size: 14, color: activeAccent),
            label: const Text(
              "Profile",
              style: TextStyle(
                color: activeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed:
                () => _openPdfDownloadDialog(id, name, pageCtrl.mainController),
            icon: const Icon(
              FontAwesomeIcons.filePdf,
              size: 14,
              color: debitColor,
            ),
            label: const Text(
              "Statement",
              style: TextStyle(color: debitColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ],
    );
  }

  // --- LIVE BALANCE HEADER ---
  Widget _buildLiveBalanceSection(
    DebatorController mainController,
    bool isMobile,
  ) {
    return StreamBuilder<Map<String, double>>(
      stream: mainController.getDebtorBreakdown(id),
      builder: (context, snap) {
        final data = snap.data ?? {'loan': 0.0, 'running': 0.0, 'total': 0.0};

        final netCard = Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "৳ ${data['total']!.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.w900,
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
        );

        final splitCards = Row(
          children: [
            Expanded(
              child: _balanceCard(
                FontAwesomeIcons.clockRotateLeft,
                "PREVIOUS LOAN",
                data['loan']!,
                Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _balanceCard(
                FontAwesomeIcons.receipt,
                "RUNNING BILLS",
                data['running']!,
                activeAccent,
              ),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            children: [netCard, const SizedBox(height: 12), splitCards],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: netCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: splitCards),
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
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
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
            "৳ ${amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- TOOLBAR ---
  Widget _buildAdvancedToolbar(
    DebtorDetailsController pageCtrl,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child:
          isMobile
              ? Column(
                children: [
                  _buildSearchField(pageCtrl),
                  const SizedBox(height: 12),
                  _buildFilterDropdown(pageCtrl),
                ],
              )
              : Row(
                children: [
                  Expanded(flex: 2, child: _buildSearchField(pageCtrl)),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: _buildFilterDropdown(pageCtrl)),
                ],
              ),
    );
  }

  Widget _buildSearchField(DebtorDetailsController pageCtrl) {
    return TextField(
      style: TextStyle(fontSize: 13),
      controller: pageCtrl.searchCtrl,
      decoration: InputDecoration(
        hintText: "Search Invoice, Note...",
        hintStyle: TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: bgGrey,
      ),
    );
  }

  Widget _buildFilterDropdown(DebtorDetailsController pageCtrl) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgGrey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: pageCtrl.filterType.value,
            icon: const Icon(Icons.filter_list, size: 18, color: Colors.grey),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: 'All',
                child: Text(
                  "All Transactions",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'Debits',
                child: Text(
                  "Debits (Sales/Bills)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'Credits',
                child: Text(
                  "Credits (Payments)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            onChanged: (v) => pageCtrl.updateFilter(v!),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TRANSACTION LIST (Responsive)
  // ==========================================
  Widget _buildTableSection(
    DebtorModel debtor,
    DebatorController mainController,
    DebtorDetailsController pageCtrl,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: GetBuilder<DebtorDetailsController>(
        tag: id,
        id: 'table_section',
        builder: (_) {
          return Obx(() {
            if (mainController.isTxLoading.value) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              );
            }

            final txList = pageCtrl.processedTransactions;

            if (isMobile) {
              if (txList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      "No transactions found matching criteria.",
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: txList.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder:
                    (context, index) => _buildMobileCard(
                      txList[index],
                      debtor,
                      mainController,
                      pageCtrl,
                    ),
              );
            } else {
              return _buildDesktopTable(
                txList,
                debtor,
                mainController,
                pageCtrl,
              );
            }
          });
        },
      ),
    );
  }

  // ==========================================
  // DESKTOP FULL-WIDTH TABLE
  // ==========================================
  Widget _buildDesktopTable(
    List<DisplayTx> txList,
    DebtorModel debtor,
    DebatorController mainController,
    DebtorDetailsController pageCtrl,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 1000 ? constraints.maxWidth : 1000.0;

        return ScrollConfiguration(
          behavior: TableScrollBehavior(),
          child: Scrollbar(
            controller: _vScroll,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _vScroll,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Center(
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: _headerCell("DATE")),
                                  Expanded(
                                    flex: 4,
                                    child: _headerCell("DETAILS / INVOICE"),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _headerCell(
                                      "DEBIT",
                                      isRight: true,
                                      color: debitColor,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _headerCell(
                                      "CREDIT",
                                      isRight: true,
                                      color: creditColor,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: _headerCell("ACTION", isRight: true),
                                  ),
                                ],
                              ),
                            ),
                            if (txList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    "No transactions found matching criteria.",
                                    style: TextStyle(
                                      color: textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: txList.length,
                                itemBuilder:
                                    (context, index) => _buildDesktopRow(
                                      txList[index],
                                      debtor,
                                      mainController,
                                      pageCtrl,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(
    String text, {
    bool isRight = false,
    Color color = textMuted,
  }) {
    return Text(
      text,
      textAlign: isRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDesktopRow(
    DisplayTx tx,
    DebtorModel debtor,
    DebatorController mainController,
    DebtorDetailsController pageCtrl,
  ) {
    final tInfo = _getTxInfo(tx);
    bool isInvoice = tInfo['invId'] != null;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat("dd MMM yyyy").format(tx.date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(tInfo['icon'], size: 10, color: tInfo['color']),
                    const SizedBox(width: 4),
                    Text(
                      tInfo['label'],
                      style: TextStyle(
                        color: tInfo['color'],
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isInvoice)
                  InkWell(
                    onTap: () => pageCtrl.printInvoice(tInfo['invId']!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tx.note.isEmpty ? "-" : tx.note,
                            style: const TextStyle(
                              fontSize: 12,
                              color: activeAccent,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.print, size: 12, color: activeAccent),
                      ],
                    ),
                  )
                else
                  Text(
                    tx.note.isEmpty ? "-" : tx.note,
                    style: const TextStyle(
                      fontSize: 12,
                      color: darkSlate,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (tx.paymentMethod != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      formatDynamicPayment(tx.paymentMethod!),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tx.debitAmount > 0
                  ? "৳ ${tx.debitAmount.toStringAsFixed(0)}"
                  : "-",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight:
                    tx.debitAmount > 0 ? FontWeight.w800 : FontWeight.normal,
                color: tx.debitAmount > 0 ? debitColor : Colors.grey.shade300,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tx.creditAmount > 0
                  ? "৳ ${tx.creditAmount.toStringAsFixed(0)}"
                  : "-",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight:
                    tx.creditAmount > 0 ? FontWeight.w800 : FontWeight.normal,
                color: tx.creditAmount > 0 ? creditColor : Colors.grey.shade300,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconBtn(Icons.edit, activeAccent, () {
                  if (tx.type == 'paid_sale') {
                    Get.snackbar(
                      "Denied",
                      "Edit this inside the Sales module.",
                      backgroundColor: Colors.orange.shade800,
                      colorText: Colors.white,
                    );
                  } else {
                    _openEditTransactionDialog(
                      tx.originalTx,
                      debtor,
                      mainController,
                    );
                  }
                }),
                _iconBtn(
                  Icons.delete,
                  Colors.red.shade400,
                  () => _openDeleteConfirmDialog(tx, id, mainController),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(
    DisplayTx tx,
    DebtorModel debtor,
    DebatorController mainController,
    DebtorDetailsController pageCtrl,
  ) {
    final tInfo = _getTxInfo(tx);
    bool isInvoice = tInfo['invId'] != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat("dd MMM yyyy").format(tx.date),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              Row(
                children: [
                  Icon(tInfo['icon'], size: 10, color: tInfo['color']),
                  const SizedBox(width: 4),
                  Text(
                    tInfo['label'],
                    style: TextStyle(
                      color: tInfo['color'],
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isInvoice)
            InkWell(
              onTap: () => pageCtrl.printInvoice(tInfo['invId']!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tx.note.isEmpty ? "-" : tx.note,
                      style: const TextStyle(
                        fontSize: 14,
                        color: activeAccent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.print, size: 14, color: activeAccent),
                ],
              ),
            )
          else
            Text(
              tx.note.isEmpty ? "-" : tx.note,
              style: const TextStyle(
                fontSize: 14,
                color: darkSlate,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),
          if (tx.paymentMethod != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                formatDynamicPayment(tx.paymentMethod!),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (tx.debitAmount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: debitColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "DR: ৳${tx.debitAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: debitColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (tx.debitAmount > 0 && tx.creditAmount > 0)
                    const SizedBox(width: 8),
                  if (tx.creditAmount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: creditColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "CR: ৳${tx.creditAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: creditColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  _iconBtn(Icons.edit, activeAccent, () {
                    if (tx.type == 'paid_sale') {
                      Get.snackbar(
                        "Denied",
                        "Edit this inside the Sales module.",
                        backgroundColor: Colors.orange.shade800,
                        colorText: Colors.white,
                      );
                    } else {
                      _openEditTransactionDialog(
                        tx.originalTx,
                        debtor,
                        mainController,
                      );
                    }
                  }),
                  _iconBtn(
                    Icons.delete,
                    Colors.red.shade400,
                    () => _openDeleteConfirmDialog(tx, id, mainController),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTxInfo(DisplayTx tx) {
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.circle;
    String typeLabel = tx.type;

    if (tx.type == 'credit') {
      typeColor = debitColor;
      typeIcon = FontAwesomeIcons.fileInvoiceDollar;
      typeLabel = "INVOICE / DUE";
    } else if (tx.type == 'paid_sale') {
      typeColor = const Color(0xFF0D9488);
      typeIcon = FontAwesomeIcons.checkDouble;
      typeLabel = "CASH SALE";
    } else if (tx.type == 'debit') {
      typeColor = creditColor;
      typeIcon = FontAwesomeIcons.handHoldingDollar;
      typeLabel = "PAYMENT";
    } else if (tx.type == 'eid_bonus') {
      typeColor = Colors.teal;
      typeIcon = FontAwesomeIcons.gift;
      typeLabel = "EID BONUS";
    } else if (tx.type == 'discount') {
      typeColor = Colors.deepPurple;
      typeIcon = FontAwesomeIcons.tag;
      typeLabel = "DISCOUNT";
    } else if (tx.type == 'advance_given') {
      typeColor = debitColor;
      typeIcon = FontAwesomeIcons.arrowRightFromBracket;
      typeLabel = "ADV GIVEN";
    } else if (tx.type == 'advance_received') {
      typeColor = creditColor;
      typeIcon = FontAwesomeIcons.arrowRightToBracket;
      typeLabel = "ADV RECV";
    } else if (tx.type == 'previous_due') {
      typeColor = Colors.orange.shade700;
      typeIcon = FontAwesomeIcons.clockRotateLeft;
      typeLabel = "OLD DEBT";
    } else if (tx.type == 'loan_payment') {
      typeColor = Colors.purple.shade600;
      typeIcon = FontAwesomeIcons.moneyBillWave;
      typeLabel = "LOAN COLLECT";
    }

    String? invId;
    if (tx.id.startsWith('GTEL')) {
      invId = tx.id.replaceAll('_pay', '');
    } else if (tx.note.contains('GTEL-')) {
      RegExp reg = RegExp(r'GTEL-\d+-\d+');
      var match = reg.firstMatch(tx.note);
      if (match != null) invId = match.group(0);
    }

    return {
      'color': typeColor,
      'icon': typeIcon,
      'label': typeLabel,
      'invId': invId,
    };
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, size: 16, color: color),
    ),
  );

  // --- PAGINATION FOOTER ---
  Widget _buildPaginationFooter(DebatorController mainController) {
    return Obx(() {
      if (mainController.currentTxPage.value == 1 &&
          !mainController.hasMoreTx.value) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed:
                mainController.currentTxPage.value > 1
                    ? () => mainController.prevTxPage(id)
                    : null,
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const Text("Prev"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: darkSlate,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Page ${mainController.currentTxPage.value}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: darkSlate,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed:
                mainController.hasMoreTx.value
                    ? () => mainController.nextTxPage(id)
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: darkSlate,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Row(
              children: [
                Text("Next"),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ==========================================
  // GETX DIALOG TRIGGERS
  // ==========================================

  void _openAddTransactionDialog(
    DebtorModel debtor,
    DebatorController mainCtrl,
  ) {
    Get.dialog(
      GetBuilder<_AddTxFormController>(
        init: _AddTxFormController(debtor.id, mainCtrl),
        builder:
            (formCtrl) =>
                _AddTransactionDialogUI(debtor: debtor, formCtrl: formCtrl),
      ),
      barrierDismissible: false,
    );
  }

  void _openEditTransactionDialog(
    TransactionModel tx,
    DebtorModel debtor,
    DebatorController mainCtrl,
  ) {
    Get.dialog(
      GetBuilder<_EditTxFormController>(
        init: _EditTxFormController(tx, debtor.id, mainCtrl),
        builder:
            (formCtrl) => _EditTransactionDialogUI(
              tx: tx,
              debtor: debtor,
              formCtrl: formCtrl,
            ),
      ),
      barrierDismissible: false,
    );
  }

  void _openDeleteConfirmDialog(
    DisplayTx tx,
    String debtorId,
    DebatorController mainCtrl,
  ) {
    final RxBool isDeleting = false.obs;
    Get.dialog(
      Builder(
        builder:
            (dialogContext) => AlertDialog(
              title: const Text(
                "Confirm Delete",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                "Are you sure you want to delete this transaction of Tk ${tx.debitAmount > 0 ? tx.debitAmount : tx.creditAmount}?",
              ),
              actions: [
                Obx(
                  () => TextButton(
                    onPressed:
                        isDeleting.value
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                    child: const Text("Cancel"),
                  ),
                ),
                Obx(
                  () => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        isDeleting.value
                            ? null
                            : () async {
                              isDeleting.value = true;
                              try {
                                if (tx.pairedTx != null) {
                                  await mainCtrl.deleteTransaction(
                                    debtorId,
                                    tx.originalTx.id,
                                  );
                                  await mainCtrl.deleteTransaction(
                                    debtorId,
                                    tx.pairedTx!.id,
                                  );
                                } else {
                                  await mainCtrl.deleteTransaction(
                                    debtorId,
                                    tx.originalTx.id,
                                  );
                                }
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
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
                            : const Text("Delete Forever"),
                  ),
                ),
              ],
            ),
      ),
      barrierDismissible: false,
    );
  }

  void _openEditProfileDialog(DebtorModel debtor, DebatorController mainCtrl) {
    Get.dialog(
      GetBuilder<_EditProfileFormController>(
        init: _EditProfileFormController(debtor, mainCtrl),
        builder:
            (formCtrl) =>
                _EditProfileDialogUI(debtor: debtor, formCtrl: formCtrl),
      ),
      barrierDismissible: false,
    );
  }

  void _openPdfDownloadDialog(
    String debtorId,
    String debtorName,
    DebatorController mainCtrl,
  ) {
    final RxString selectedFilter = 'All Time'.obs;
    final Rx<DateTimeRange?> customRange = Rx<DateTimeRange?>(null);

    Get.dialog(
      Builder(
        builder:
            (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(FontAwesomeIcons.filePdf, color: debitColor, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Export Statement",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select the timeframe for this ledger report:",
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: bgGrey,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Obx(
                      () => DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFilter.value,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'Last 3 Days',
                              child: Text(
                                "Last 3 Days",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Last 7 Days',
                              child: Text(
                                "Last 7 Days",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Last 30 Days',
                              child: Text(
                                "Last 30 Days",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Last 90 Days',
                              child: Text(
                                "Last 90 Days",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'All Time',
                              child: Text(
                                "All Time (Full Ledger)",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Custom Range',
                              child: Text(
                                "Custom Date Range...",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val == 'Custom Range') {
                              DateTimeRange? picked = await showDateRangePicker(
                                context: dialogContext,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: darkSlate,
                                        onPrimary: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                customRange.value = picked;
                                selectedFilter.value = val!;
                              }
                            } else if (val != null) {
                              selectedFilter.value = val;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  Obx(() {
                    if (selectedFilter.value == 'Custom Range' &&
                        customRange.value != null) {
                      final start = DateFormat(
                        'dd MMM yyyy',
                      ).format(customRange.value!.start);
                      final end = DateFormat(
                        'dd MMM yyyy',
                      ).format(customRange.value!.end);
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: activeAccent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: activeAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.date_range,
                                size: 16,
                                color: activeAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "$start  ➔  $end",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: darkSlate,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  DateTimeRange? picked =
                                      await showDateRangePicker(
                                        context: dialogContext,
                                        initialDateRange: customRange.value,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                  if (picked != null) {
                                    customRange.value = picked;
                                  }
                                },
                                child: const Text(
                                  "Change",
                                  style: TextStyle(
                                    color: activeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: debitColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    DateTimeRange? range;
                    DateTime now = DateTime.now();

                    if (selectedFilter.value == 'Last 3 Days') {
                      range = DateTimeRange(
                        start: now.subtract(const Duration(days: 3)),
                        end: now,
                      );
                    } else if (selectedFilter.value == 'Last 7 Days') {
                      range = DateTimeRange(
                        start: now.subtract(const Duration(days: 7)),
                        end: now,
                      );
                    } else if (selectedFilter.value == 'Last 30 Days') {
                      range = DateTimeRange(
                        start: now.subtract(const Duration(days: 30)),
                        end: now,
                      );
                    } else if (selectedFilter.value == 'Last 90 Days') {
                      range = DateTimeRange(
                        start: now.subtract(const Duration(days: 90)),
                        end: now,
                      );
                    } else if (selectedFilter.value == 'Custom Range') {
                      if (customRange.value == null) {
                        Get.snackbar(
                          "Missing Info",
                          "Please select a valid date range.",
                          backgroundColor: Colors.red.shade600,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      range = customRange.value;
                    }

                    Navigator.of(dialogContext).pop();

                    mainCtrl.selectedDateRange.value = range;
                    mainCtrl
                        .downloadFullDebtorStatement(debtorId, debtorName)
                        .then((_) {
                          mainCtrl.setDateFilter(null, debtorId);
                        });
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text(
                    "Generate PDF",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

// ============================================================================
// DIALOG CONTROLLERS & UIs (100% GetX - No setState)
// ============================================================================

class _AddTxFormController extends GetxController {
  final String debtorId;
  final DebatorController mainCtrl;
  _AddTxFormController(this.debtorId, this.mainCtrl);

  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final bankNameC = TextEditingController();
  final accountNoC = TextEditingController();
  final mobileNoC = TextEditingController();

  final RxString selectedType = 'credit'.obs;
  final RxString payMethodType = 'cash'.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxBool isSubmitting = false.obs;

  @override
  void onClose() {
    amountC.dispose();
    noteC.dispose();
    bankNameC.dispose();
    accountNoC.dispose();
    mobileNoC.dispose();
    super.onClose();
  }

  Future<void> save(BuildContext context) async {
    if (amountC.text.isEmpty) return;
    isSubmitting.value = true;
    try {
      Map<String, dynamic> pm = {'type': 'cash'};
      if (selectedType.value == 'eid_bonus') {
        pm = {'type': 'eid_bonus'};
      } else if (selectedType.value == 'discount') {
        pm = {'type': 'discount'};
      } else if ([
        'debit',
        'loan_payment',
        'advance_received',
        'advance_given',
      ].contains(selectedType.value)) {
        if (payMethodType.value == 'bank') {
          pm = {
            'type': 'bank',
            'bankName': bankNameC.text.trim(),
            'accountNo': accountNoC.text.trim(),
          };
        } else if (['bkash', 'nagad', 'rocket'].contains(payMethodType.value)) {
          pm = {'type': payMethodType.value, 'number': mobileNoC.text.trim()};
        }
      }
      await mainCtrl.addTransaction(
        debtorId: debtorId,
        amount: double.tryParse(amountC.text) ?? 0,
        note: noteC.text,
        type: selectedType.value,
        date: selectedDate.value,
        paymentMethodData: pm,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to add transaction");
    } finally {
      isSubmitting.value = false;
    }
  }
}

class _AddTransactionDialogUI extends StatelessWidget {
  final DebtorModel debtor;
  final _AddTxFormController formCtrl;

  const _AddTransactionDialogUI({required this.debtor, required this.formCtrl});

  Widget _buildField(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool isNum = false,
  }) {
    return TextField(
      style: TextStyle(fontSize: 13),
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 16, color: textMuted),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13),
        filled: true,
        fillColor: bgGrey,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
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
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Text(
                "New Transaction Entry",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildField(
                      formCtrl.amountC,
                      "Amount (Tk)",
                      Icons.attach_money,
                      isNum: true,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      formCtrl.noteC,
                      "Note / Description",
                      Icons.note,
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: bgGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: formCtrl.selectedType.value,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'credit',
                                child: Text(
                                  "🧾  New Sale/Bill (Debit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'debit',
                                child: Text(
                                  "💵  Receive Payment (Credit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'discount',
                                child: Text(
                                  "🏷️  Give Discount (Credit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'eid_bonus',
                                child: Text(
                                  "🎁  Give Eid Bonus (Credit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'previous_due',
                                child: Text(
                                  "🏦  Add Old Debt (Debit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'loan_payment',
                                child: Text(
                                  "💰  Collect Old Debt (Credit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'advance_received',
                                child: Text(
                                  "⬅️  Receive Advance (Credit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'advance_given',
                                child: Text(
                                  "➡️  Give Advance (Debit)",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) formCtrl.selectedType.value = v;
                            },
                          ),
                        ),
                      ),
                    ),
                    Obx(() {
                      if ([
                        'debit',
                        'loan_payment',
                        'advance_received',
                        'advance_given',
                      ].contains(formCtrl.selectedType.value)) {
                        return Column(
                          children: [
                            const SizedBox(height: 16),
                            const Divider(),
                            _buildDynamicPaymentSection(),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Obx(
                          () => TextButton(
                            onPressed:
                                formCtrl.isSubmitting.value
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                formCtrl.isSubmitting.value
                                    ? null
                                    : () => formCtrl.save(context),
                            child:
                                formCtrl.isSubmitting.value
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
                                        fontSize: 13,
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
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicPaymentSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Obx(
            () => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: formCtrl.payMethodType.value,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Row(
                      children: [
                        Icon(Icons.money, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Cash", style: TextStyle(fontSize: 13)),
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
                        Text("Bank Transfer", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'bkash',
                    child: Row(
                      children: [
                        Icon(
                          Icons.mobile_friendly,
                          size: 16,
                          color: Colors.pink,
                        ),
                        SizedBox(width: 8),
                        Text("Bkash", style: TextStyle(fontSize: 13)),
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
                        Text("Nagad", style: TextStyle(fontSize: 13)),
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
                        Text("Rocket", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                onChanged: (v) {
                  formCtrl.payMethodType.value = v!;
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          if (formCtrl.payMethodType.value == 'bank') {
            return Column(
              children: [
                _buildField(
                  formCtrl.bankNameC,
                  "Bank Name (e.g. Islami Bank)",
                  Icons.business,
                ),
                const SizedBox(height: 8),
                _buildField(
                  formCtrl.accountNoC,
                  "Account Number",
                  Icons.numbers,
                ),
              ],
            );
          } else if ([
            'bkash',
            'nagad',
            'rocket',
          ].contains(formCtrl.payMethodType.value)) {
            return _buildField(
              formCtrl.mobileNoC,
              "${formCtrl.payMethodType.value.capitalizeFirst} Number",
              Icons.phone_android,
              isNum: true,
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}

class _EditTxFormController extends GetxController {
  final TransactionModel tx;
  final String debtorId;
  final DebatorController mainCtrl;
  _EditTxFormController(this.tx, this.debtorId, this.mainCtrl);

  late TextEditingController amountC, noteC, bankNameC, accountNoC, mobileNoC;
  late RxString selectedType, payMethodType;
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    amountC = TextEditingController(text: tx.amount.toString());
    noteC = TextEditingController(text: tx.note);
    selectedType = tx.type.obs;

    final map = tx.paymentMethod ?? {'type': 'cash'};
    payMethodType = (map['type'] ?? 'cash').toString().toLowerCase().obs;
    bankNameC = TextEditingController(text: map['bankName'] ?? '');
    accountNoC = TextEditingController(text: map['accountNo'] ?? '');
    mobileNoC = TextEditingController(text: map['number'] ?? '');
  }

  @override
  void onClose() {
    amountC.dispose();
    noteC.dispose();
    bankNameC.dispose();
    accountNoC.dispose();
    mobileNoC.dispose();
    super.onClose();
  }

  Future<void> save(BuildContext context) async {
    isSubmitting.value = true;
    try {
      Map<String, dynamic> pm = {'type': 'cash'};
      if (selectedType.value == 'eid_bonus') {
        pm = {'type': 'eid_bonus'};
      } else if (selectedType.value == 'discount') {
        pm = {'type': 'discount'};
      } else if ([
        'debit',
        'loan_payment',
        'advance_received',
        'advance_given',
      ].contains(selectedType.value)) {
        if (payMethodType.value == 'bank') {
          pm = {
            'type': 'bank',
            'bankName': bankNameC.text.trim(),
            'accountNo': accountNoC.text.trim(),
          };
        } else if (['bkash', 'nagad', 'rocket'].contains(payMethodType.value)) {
          pm = {'type': payMethodType.value, 'number': mobileNoC.text.trim()};
        }
      }
      await mainCtrl.editTransaction(
        debtorId: debtorId,
        transactionId: tx.id,
        oldAmount: tx.amount,
        newAmount: double.tryParse(amountC.text) ?? 0,
        oldType: tx.type,
        newType: selectedType.value,
        note: noteC.text,
        date: tx.date,
        paymentMethod: pm,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to update transaction");
    } finally {
      isSubmitting.value = false;
    }
  }
}

class _EditTransactionDialogUI extends StatelessWidget {
  final TransactionModel tx;
  final DebtorModel debtor;
  final _EditTxFormController formCtrl;

  const _EditTransactionDialogUI({
    required this.tx,
    required this.debtor,
    required this.formCtrl,
  });

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
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
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
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Text(
                "Edit Transaction",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildField(
                      formCtrl.amountC,
                      "Amount",
                      Icons.money,
                      isNum: true,
                    ),
                    const SizedBox(height: 12),
                    _buildField(formCtrl.noteC, "Note", Icons.edit),
                    const SizedBox(height: 12),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: bgGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: formCtrl.selectedType.value,
                            isExpanded: true,
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
                                value: 'discount',
                                child: Text("DISCOUNT"),
                              ),
                              DropdownMenuItem(
                                value: 'eid_bonus',
                                child: Text("EID BONUS"),
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
                            onChanged: (v) {
                              formCtrl.selectedType.value = v!;
                            },
                          ),
                        ),
                      ),
                    ),
                    Obx(() {
                      if ([
                        'debit',
                        'loan_payment',
                        'advance_received',
                        'advance_given',
                      ].contains(formCtrl.selectedType.value)) {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            const Divider(),
                            _buildDynamicPaymentSection(),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Obx(
                          () => TextButton(
                            onPressed:
                                formCtrl.isSubmitting.value
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                formCtrl.isSubmitting.value
                                    ? null
                                    : () => formCtrl.save(context),
                            child:
                                formCtrl.isSubmitting.value
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
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicPaymentSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Obx(
            () => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: formCtrl.payMethodType.value,
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
                        Icon(
                          Icons.mobile_friendly,
                          size: 16,
                          color: Colors.pink,
                        ),
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
                onChanged: (v) {
                  formCtrl.payMethodType.value = v!;
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          if (formCtrl.payMethodType.value == 'bank') {
            return Column(
              children: [
                _buildField(
                  formCtrl.bankNameC,
                  "Bank Name (e.g. Islami Bank)",
                  Icons.business,
                ),
                const SizedBox(height: 8),
                _buildField(
                  formCtrl.accountNoC,
                  "Account Number",
                  Icons.numbers,
                ),
              ],
            );
          } else if ([
            'bkash',
            'nagad',
            'rocket',
          ].contains(formCtrl.payMethodType.value)) {
            return _buildField(
              formCtrl.mobileNoC,
              "${formCtrl.payMethodType.value.capitalizeFirst} Number",
              Icons.phone_android,
              isNum: true,
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}

class _EditProfileFormController extends GetxController {
  final DebtorModel debtor;
  final DebatorController mainCtrl;
  _EditProfileFormController(this.debtor, this.mainCtrl);

  late TextEditingController nameC, phoneC, nidC, addressC, desC;
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    nameC = TextEditingController(text: debtor.name);
    phoneC = TextEditingController(text: debtor.phone);
    nidC = TextEditingController(text: debtor.nid);
    addressC = TextEditingController(text: debtor.address);
    desC = TextEditingController(text: debtor.des);
  }

  @override
  void onClose() {
    nameC.dispose();
    phoneC.dispose();
    nidC.dispose();
    addressC.dispose();
    desC.dispose();
    super.onClose();
  }

  Future<void> save(BuildContext context) async {
    isSubmitting.value = true;
    try {
      await mainCtrl.editDebtor(
        id: debtor.id,
        oldName: debtor.name,
        newName: nameC.text,
        des: desC.text,
        nid: nidC.text,
        phone: phoneC.text,
        address: addressC.text,
        payments: debtor.payments,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to update profile");
    } finally {
      isSubmitting.value = false;
    }
  }
}

class _EditProfileDialogUI extends StatelessWidget {
  final DebtorModel debtor;
  final _EditProfileFormController formCtrl;

  const _EditProfileDialogUI({required this.debtor, required this.formCtrl});

  Widget _buildField(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 16, color: textMuted),
        hintText: hint,
        filled: true,
        fillColor: bgGrey,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Edit Profile",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField(formCtrl.nameC, "Name", Icons.person),
            const SizedBox(height: 8),
            _buildField(formCtrl.phoneC, "Phone", Icons.phone),
            const SizedBox(height: 8),
            _buildField(formCtrl.nidC, "NID", Icons.badge),
            const SizedBox(height: 8),
            _buildField(formCtrl.addressC, "Address", Icons.home),
            const SizedBox(height: 8),
            _buildField(formCtrl.desC, "Description", Icons.description),
          ],
        ),
      ),
      actions: [
        Obx(
          () => TextButton(
            onPressed:
                formCtrl.isSubmitting.value
                    ? null
                    : () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ),
        Obx(
          () => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed:
                formCtrl.isSubmitting.value
                    ? null
                    : () => formCtrl.save(context),
            child:
                formCtrl.isSubmitting.value
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text("Save"),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================
String formatDynamicPayment(Map<String, dynamic> pm) {
  String type = (pm['type'] ?? 'Cash').toString().toUpperCase();
  if (type == 'EID_BONUS') return "Eid Bonus";
  if (type == 'DISCOUNT') return "Discount";
  if (type == 'BANK') {
    return "BANK: ${pm['bankName'] ?? ''}\nACC: ${pm['accountNo'] ?? ''}";
  }
  if (['BKASH', 'NAGAD', 'ROCKET'].contains(type)) {
    return "$type: ${pm['number'] ?? ''}";
  }
  return type;
}
