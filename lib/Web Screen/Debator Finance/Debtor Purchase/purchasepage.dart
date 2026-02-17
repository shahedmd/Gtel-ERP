// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// IMPORTANT: Ensure these match your project structure
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/dialog.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';

class DebtorPurchasePage extends StatelessWidget {
  final String debtorId;
  final String debtorName;

  DebtorPurchasePage({
    super.key,
    required this.debtorId,
    required this.debtorName,
  });

  // Inject the controller
  final DebtorPurchaseController controller =
      Get.isRegistered<DebtorPurchaseController>()
          ? Get.find<DebtorPurchaseController>()
          : Get.put(DebtorPurchaseController());

  // THEME COLORS (ERP Standard)
  static const Color darkSlate = Color(0xFF111827); // Dark header
  static const Color activeAccent = Color(0xFF3B82F6); // Blue
  static const Color bgGrey = Color(0xFFF3F4F6); // Main background
  static const Color surfaceWhite = Colors.white;
  static const Color borderCol = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);

  static const Color creditRed = Color(0xFFEF4444);
  static const Color debitGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    // Initial Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadPurchases(debtorId);
    });

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Purchases Ledger",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              debtorName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: darkSlate,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.loadPurchases(debtorId),
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. STATS DASHBOARD
          _buildStatsHeader(),

          // 2. ACTION TOOLBAR
          _buildActionToolbar(context),

          const Divider(height: 1, color: borderCol),

          // 3. DATA TABLE HEADER
          _buildTableHeader(),

          // 4. DATA TABLE BODY (Expanded)
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: activeAccent),
                );
              }
              if (controller.purchases.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: controller.purchases.length,
                separatorBuilder:
                    (c, i) => const Divider(height: 1, color: borderCol),
                itemBuilder: (context, index) {
                  final item = controller.purchases[index];
                  return _buildTableRow(context, item);
                },
              );
            }),
          ),

          // 5. PAGINATION FOOTER
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. STATS DASHBOARD
  // ===========================================================================
  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      color: darkSlate,
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              "TOTAL PURCHASED",
              controller.totalPurchased,
              Colors.white,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _statCard("TOTAL PAID", controller.totalPaid, debitGreen),
            ),
          ),

          // Net Balance Highlight
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "NET PAYABLE DUE",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tk ${controller.currentPayable.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: creditRed,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, RxDouble val, Color valColor) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tk ${val.value.toStringAsFixed(0)}",
            style: TextStyle(
              color: valColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. ACTION TOOLBAR
  // ===========================================================================
  Widget _buildActionToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: surfaceWhite,
      child: Row(
        children: [
          Expanded(
            child: _actionBtn(
              label: "New Purchase",
              icon: Icons.add_shopping_cart,
              bgColor: activeAccent,
              textColor: Colors.white,
              onTap: () => showPurchaseDialog(context, debtorId),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn(
              label: "Pay Vendor",
              icon: Icons.payments,
              bgColor: debitGreen,
              textColor: Colors.white,
              onTap: () => _showPaymentDialogWithDate(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn(
              label: "Contra Adjust",
              icon: Icons.compare_arrows,
              bgColor: Colors.white,
              textColor: Colors.orange[800]!,
              borderColor: Colors.orange[200]!,
              onTap: () => _showContraDialogWithDate(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16, color: textColor),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 18),
        side: borderColor != null ? BorderSide(color: borderColor) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onPressed: onTap,
    );
  }

  // ===========================================================================
  // 3. TABLE HEADER
  // ===========================================================================
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB), // Very light grey
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text("DATE", style: _headStyle)),
          Expanded(flex: 2, child: Text("TYPE", style: _headStyle)),
          Expanded(
            flex: 4,
            child: Text("DESCRIPTION / NOTE", style: _headStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "AMOUNT",
              textAlign: TextAlign.right,
              style: _headStyle,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text("ACT", textAlign: TextAlign.center, style: _headStyle),
          ),
        ],
      ),
    );
  }

  static const TextStyle _headStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: textMuted,
    letterSpacing: 0.5,
  );

  // ===========================================================================
  // 4. TABLE ROW
  // ===========================================================================
  Widget _buildTableRow(BuildContext context, Map<String, dynamic> item) {
    // Determine visuals based on type
    final String type = item['type'] ?? '';
    final bool isInvoice = type == 'invoice';
    final bool isAdj = type == 'adjustment';
    final bool isPay = type == 'payment';

    // Badge Config
    Color badgeBg = Colors.grey[100]!;
    Color badgeText = Colors.grey;
    String badgeLabel = "UNKNOWN";

    if (isInvoice) {
      badgeBg = activeAccent.withOpacity(0.1);
      badgeText = activeAccent;
      badgeLabel = "PURCHASE";
    } else if (isPay) {
      badgeBg = debitGreen.withOpacity(0.1);
      badgeText = debitGreen;
      badgeLabel = "PAYMENT";
    } else if (isAdj) {
      badgeBg = warningOrange.withOpacity(0.1);
      badgeText = warningOrange;
      badgeLabel = "CONTRA";
    }

    // Amount Config
    String amountPrefix = isInvoice ? "+" : "-";
    Color amountColor =
        isInvoice ? textDark : (isAdj ? warningOrange : debitGreen);

    // Safe Date Parsing
    DateTime dateObj = DateTime.now();
    if (item['date'] is Timestamp) {
      dateObj = (item['date'] as Timestamp).toDate();
    }

    return InkWell(
      onTap: isInvoice ? () => _showPurchaseDetails(context, item) : null,
      hoverColor: Colors.grey[50],
      child: Container(
        color: surfaceWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // DATE
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd MMM yyyy').format(dateObj),
                style: const TextStyle(
                  fontSize: 13,
                  color: textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // TYPE BADGE
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DESCRIPTION
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item['note'] != null &&
                      item['note'].toString().isNotEmpty)
                    Text(
                      item['note'],
                      style: const TextStyle(fontSize: 12, color: textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      isInvoice
                          ? "Stock Purchase Invoice"
                          : (isAdj
                              ? "Contra Ledger Adjustment"
                              : "Cash Payment to Vendor"),
                      style: const TextStyle(
                        fontSize: 12,
                        color: textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (isInvoice)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "ID: ${item['id'].toString().substring(0, 8).toUpperCase()}",
                        style: const TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ),
                ],
              ),
            ),

            // AMOUNT
            Expanded(
              flex: 2,
              child: Text(
                "$amountPrefix${(item['totalAmount'] ?? item['amount']).toString()}",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                  fontFamily: 'Roboto',
                  fontSize: 13,
                ),
              ),
            ),

            // ACTION ICON
            SizedBox(
              width: 50,
              child:
                  isInvoice
                      ? const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 16,
                        color: textMuted,
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            "No purchase history yet",
            style: TextStyle(color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: surfaceWhite,
        border: Border(top: BorderSide(color: borderCol)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => ElevatedButton.icon(
              onPressed:
                  controller.isFirstPage.value
                      ? null
                      : () => controller.previousPage(debtorId),
              icon: const Icon(Icons.chevron_left, size: 16),
              label: const Text("Previous"),
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceWhite,
                foregroundColor: textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: const BorderSide(color: borderCol),
                disabledBackgroundColor: bgGrey,
                disabledForegroundColor: textMuted,
              ),
            ),
          ),
          Obx(
            () => ElevatedButton(
              onPressed:
                  controller.hasMore.value
                      ? () => controller.nextPage(debtorId)
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceWhite,
                foregroundColor: textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: const BorderSide(color: borderCol),
                disabledBackgroundColor: bgGrey,
                disabledForegroundColor: textMuted,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("Next"),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. DIALOG LOGIC
  // ===========================================================================

  void _showPurchaseDetails(BuildContext context, Map<String, dynamic> item) {
    // Kept original implementation for details view
    List items = item['items'] ?? [];
    double total = double.tryParse(item['totalAmount'].toString()) ?? 0.0;

    DateTime dateObj = DateTime.now();
    if (item['date'] is Timestamp)
      dateObj = (item['date'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 600,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: darkSlate,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Purchase Invoice Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        InkWell(
                          onTap: () => Get.back(),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _infoBox(
                                "Date",
                                DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(dateObj),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _infoBox("Note", item['note'] ?? 'N/A'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: borderCol),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                color: bgGrey,
                                child: Row(
                                  children: const [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        "ITEM",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "QTY",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "TOTAL",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 250,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children:
                                        items
                                            .map(
                                              (e) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 12,
                                                    ),
                                                decoration: const BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: borderCol,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 4,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            e['name'] ?? '',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      textDark,
                                                                ),
                                                          ),
                                                          Text(
                                                            "${e['model']} • ${e['location']}",
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      textMuted,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        e['qty'].toString(),
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        e['subtotal']
                                                            .toString(),
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "INVOICE TOTAL",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textMuted,
                                  ),
                                ),
                                Text(
                                  "Tk $total",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                            Obx(
                              () => ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: activeAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed:
                                    controller.isGeneratingPdf.value
                                        ? null
                                        : () => controller.generatePurchasePdf(
                                          item,
                                          debtorName,
                                        ),
                                icon:
                                    controller.isGeneratingPdf.value
                                        ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.print,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                label: const Text(
                                  "Download Invoice",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // --- UPDATED PAYMENT DIALOG WITH DATE ---
  void _showPaymentDialogWithDate(BuildContext context) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    // Use State variable for Date inside StatefulBuilder
    DateTime selectedDate = DateTime.now();
    final dateC = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 400,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Record Payment Out",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Pay Cash to this debtor. This will be recorded as an Expense.",
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 20),

                    // DATE PICKER FIELD
                    TextField(
                      controller: dateC,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Payment Date",
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                            dateC.text = DateFormat(
                              'dd-MMM-yyyy',
                            ).format(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    // AMOUNT FIELD
                    TextField(
                      controller: amountC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                        prefixText: "Tk ",
                      ),
                    ),
                    const SizedBox(height: 15),

                    // NOTE FIELD
                    TextField(
                      controller: noteC,
                      decoration: const InputDecoration(
                        labelText: "Note (Optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: debitGreen,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () {
                          controller.makePayment(
                            debtorId: debtorId,
                            debtorName: debtorName,
                            amount: double.tryParse(amountC.text) ?? 0,
                            method: "Cash",
                            note: noteC.text,
                            customDate: selectedDate, // Pass selected date
                          );
                          // Controller handles Get.back()
                        },
                        child: const Text(
                          "Confirm Payment",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // --- UPDATED CONTRA DIALOG WITH DATE ---
  void _showContraDialogWithDate(BuildContext context) {
    final amountC = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final dateC = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 400,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.compare_arrows, color: Colors.orange),
                        SizedBox(width: 10),
                        Text(
                          "Contra Adjustment",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkSlate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "This will deduct the amount from 'Payable Due' and also deduct from 'Receivable Due' in the Debtor's Sales Ledger.",
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Obx(
                      () => Text(
                        "Max Adjust: ${controller.currentPayable.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // DATE PICKER
                    TextField(
                      controller: dateC,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Adjustment Date",
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                            dateC.text = DateFormat(
                              'dd-MMM-yyyy',
                            ).format(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: amountC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Adjustment Amount",
                        border: OutlineInputBorder(),
                        prefixText: "Tk ",
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkSlate,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () {
                          controller.processContraAdjustment(
                            debtorId: debtorId,
                            amount: double.tryParse(amountC.text) ?? 0,
                            customDate: selectedDate, // Pass selected date
                          );
                        },
                        child: const Text(
                          "Process Adjustment",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _infoBox(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: textMuted)),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(
            fontSize: 13,
            color: textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}