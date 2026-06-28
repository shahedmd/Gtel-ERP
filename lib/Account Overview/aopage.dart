// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:gtel_erp/Account%20Overview/controllerao.dart';
import 'package:gtel_erp/Cash/controller.dart';

class FinancialOverviewPage extends StatelessWidget {
  const FinancialOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FinancialController());
    final cashCtrl = Get.put(CashDrawerController());

    final currency = NumberFormat.currency(
      locale: 'en_BD',
      symbol: '৳',
      decimalDigits: 0,
    );
    final compactCurrency = NumberFormat.compactSimpleCurrency(name: '৳');

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isMobile = screenWidth < 700;
    final bool isDesktop = screenWidth >= 900;

    const Color bgSlate = Color(0xFFF8FAFC);
    const Color darkHeader = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgSlate,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "EXECUTIVE SUMMARY",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontSize: isMobile ? 15 : 18,
                color: Colors.white,
              ),
            ),
            Text(
              "Financial Health Report",
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: darkHeader,
        elevation: 0,
        actions: [
          // ── Year-End Close button ──
          Obx(
            () =>
                controller.isLoading.value
                    ? const SizedBox.shrink()
                    : IconButton(
                      icon: const Icon(Icons.lock_clock, color: Colors.white),
                      tooltip: "Close Financial Year",
                      onPressed:
                          () => _showCloseYearDialog(
                            context,
                            controller,
                            currency,
                          ),
                    ),
          ),
          // ── Closed Years / Compare button ──
          Obx(
            () =>
                controller.closedYearReports.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                      icon: const Icon(Icons.history_edu, color: Colors.amber),
                      tooltip: "Closed Year Reports",
                      onPressed:
                          () => _showClosedYearsSheet(
                            context,
                            controller,
                            currency,
                          ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: "Print Report",
            onPressed:
                () => controller.generateAndPrintPDF(
                  compareWith: controller.comparisonReport.value,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: "Refresh Data",
            onPressed: () => controller.refreshExternalData(),
          ),
          if (!isMobile) const SizedBox(width: 12),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _ShimmerSkeleton(isMobile: isMobile, isDesktop: isDesktop);
        }
        return RefreshIndicator(
          onRefresh: () => controller.refreshExternalData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Comparison Banner ──
                      Obx(() {
                        final cmp = controller.comparisonReport.value;
                        if (cmp == null) return const SizedBox.shrink();
                        return _ComparisonBanner(
                          year: cmp.year,
                          onClear: () => controller.setComparison(null),
                        );
                      }),

                      _buildTopKPIs(controller, currency, isMobile),

                      SizedBox(height: isMobile ? 20 : 30),

                      Flex(
                        direction: isDesktop ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isDesktop ? 1 : 0,
                            child: _buildAssetsColumn(
                              controller,
                              cashCtrl,
                              currency,
                              compactCurrency,
                              context,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 24 : 0,
                            height: isDesktop ? 0 : 24,
                          ),
                          Expanded(
                            flex: isDesktop ? 1 : 0,
                            child: _buildLiabilitiesColumn(
                              controller,
                              currency,
                              context,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _buildFinalEquation(controller, currency, isMobile),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ───────────────────────────────────────────────
  // KPI Cards
  // ───────────────────────────────────────────────
  Widget _buildTopKPIs(
    FinancialController ctrl,
    NumberFormat fmt,
    bool isMobile,
  ) {
    return Obx(() {
      final cmp = ctrl.comparisonReport.value;
      return Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        children: [
          Expanded(
            flex: isMobile ? 0 : 1,
            child: _SummaryTile(
              label: "Total Business Value",
              subLabel: "(What You Own)",
              amount: ctrl.grandTotalAssets,
              icon: FontAwesomeIcons.buildingColumns,
              color: const Color(0xFF059669),
              formatter: fmt,
              prevAmount: cmp?.totalAssets,
            ),
          ),
          SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
          Expanded(
            flex: isMobile ? 0 : 1,
            child: _SummaryTile(
              label: "Total Debt",
              subLabel: "(What You Owe)",
              amount: ctrl.grandTotalLiabilities,
              icon: FontAwesomeIcons.fileInvoiceDollar,
              color: const Color(0xFFDC2626),
              formatter: fmt,
              prevAmount: cmp?.totalLiabilities,
              invertDelta: true,
            ),
          ),
          SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
          Expanded(
            flex: isMobile ? 0 : 1,
            child: _SummaryTile(
              label: "Real Profit / Equity",
              subLabel: "(Your Actual Money)",
              amount: ctrl.netWorth,
              icon: FontAwesomeIcons.chartLine,
              color: const Color(0xFF2563EB),
              formatter: fmt,
              isHighlight: true,
              prevAmount: cmp?.netWorth,
            ),
          ),
        ],
      );
    });
  }

  // ───────────────────────────────────────────────
  // Assets Column
  // ───────────────────────────────────────────────
  Widget _buildAssetsColumn(
    FinancialController ctrl,
    CashDrawerController cashCtrl,
    NumberFormat fmt,
    NumberFormat compact,
    BuildContext context,
  ) {
    return Column(
      children: [
        _ErpSectionHeader(
          title: "WHAT YOU HAVE (ASSETS)",
          color: Colors.teal[800]!,
        ),
        const SizedBox(height: 12),
        _ErpCard(
          title: "Cash & Bank Balance",
          icon: FontAwesomeIcons.wallet,
          accentColor: Colors.teal,
          child: Obx(
            () => Column(
              children: [
                _StatRow("Cash Drawer", cashCtrl.netCash.value, fmt),
                _StatRow("Bank Accounts", cashCtrl.netBank.value, fmt),
                _StatRow("bKash Wallet", cashCtrl.netBkash.value, fmt),
                _StatRow("Nagad Wallet", cashCtrl.netNagad.value, fmt),
                const Divider(height: 24),
                _StatRow(
                  "TOTAL LIQUID CASH",
                  ctrl.totalCash,
                  fmt,
                  isBold: true,
                  color: Colors.teal[800],
                  prevAmount: ctrl.comparisonReport.value?.cash,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ErpCard(
          title: "Inventory & Pending Collections",
          icon: FontAwesomeIcons.boxesStacked,
          accentColor: Colors.blueGrey,
          action: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blueGrey),
            onPressed: () => _showAddAssetDialog(context, ctrl),
          ),
          child: Obx(
            () => Column(
              children: [
                _StatRow(
                  "Stock Valuation",
                  ctrl.totalStockValuation,
                  fmt,
                  prevAmount: ctrl.comparisonReport.value?.stockValuation,
                ),
                _StatRow(
                  "Incoming Shipments",
                  ctrl.totalShipmentValuation,
                  fmt,
                  prevAmount: ctrl.comparisonReport.value?.shipmentValuation,
                ),
                _StatRow(
                  "Customers Owe You",
                  ctrl.totalDebtorReceivables,
                  fmt,
                  color: Colors.orange[800],
                  prevAmount: ctrl.comparisonReport.value?.debtorReceivables,
                ),
                _StatRow(
                  "Loans Given to Staff",
                  ctrl.totalEmployeeDebt,
                  fmt,
                  prevAmount: ctrl.comparisonReport.value?.employeeDebt,
                ),
                const Divider(height: 20),
                if (ctrl.fixedAssets.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "EQUIPMENT & FURNITURE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...ctrl.fixedAssets.map(
                    (asset) => _ManualItemRow(
                      label: asset.name,
                      amount: asset.value,
                      compactFmt: compact,
                      onDelete: () => ctrl.deleteAsset(asset.id!),
                    ),
                  ),
                  const Divider(height: 20),
                ],
                _StatRow(
                  "TOTAL ASSETS VALUE",
                  ctrl.grandTotalAssets,
                  fmt,
                  isBold: true,
                  color: Colors.blueGrey[800],
                  prevAmount: ctrl.comparisonReport.value?.totalAssets,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // Liabilities Column
  // ───────────────────────────────────────────────
  Widget _buildLiabilitiesColumn(
    FinancialController ctrl,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return Column(
      children: [
        _ErpSectionHeader(
          title: "WHAT YOU OWE (LIABILITIES)",
          color: Colors.red[800]!,
        ),
        const SizedBox(height: 12),
        _ErpCard(
          title: "Suppliers & Dues",
          icon: FontAwesomeIcons.handHoldingDollar,
          accentColor: Colors.red[700]!,
          child: Obx(
            () => Column(
              children: [
                _StatRow(
                  "To Pay Suppliers",
                  ctrl.totalVendorDue,
                  fmt,
                  color: Colors.red[700],
                  prevAmount: ctrl.comparisonReport.value?.vendorDue,
                  invertDelta: true,
                ),
                _StatRow(
                  "To Pay Customers",
                  ctrl.totalDebtorPayable,
                  fmt,
                  prevAmount: ctrl.comparisonReport.value?.debtorPayable,
                  invertDelta: true,
                ),
                const Divider(height: 24),
                _StatRow(
                  "TOTAL PAYABLES",
                  ctrl.totalVendorDue + ctrl.totalDebtorPayable,
                  fmt,
                  isBold: true,
                  color: Colors.red[900],
                  prevAmount:
                      ctrl.comparisonReport.value != null
                          ? (ctrl.comparisonReport.value!.vendorDue +
                              ctrl.comparisonReport.value!.debtorPayable)
                          : null,
                  invertDelta: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ErpCard(
          title: "Monthly Fixed Costs",
          icon: FontAwesomeIcons.calendarCheck,
          accentColor: Colors.orange[800]!,
          action: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
            onPressed: () => _showAddExpenseDialog(context, ctrl),
          ),
          child: Obx(
            () => Column(
              children: [
                if (ctrl.recurringExpenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "No fixed monthly costs added.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ...ctrl.recurringExpenses.map(
                  (item) => _ManualItemRow(
                    label: item.title,
                    amount: item.monthlyAmount,
                    compactFmt: fmt,
                    onDelete: () => ctrl.deleteRecurringExpense(item.id!),
                  ),
                ),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _StatRow(
                    "TOTAL MONTHLY BURN",
                    ctrl.totalMonthlyPayroll,
                    fmt,
                    isBold: true,
                    color: Colors.deepOrange,
                    prevAmount: ctrl.comparisonReport.value?.monthlyPayroll,
                    invertDelta: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // Final Equation Block
  // ───────────────────────────────────────────────
  Widget _buildFinalEquation(
    FinancialController ctrl,
    NumberFormat fmt,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "FINAL BALANCE SHEET",
            style: TextStyle(
              color: Colors.white54,
              letterSpacing: 2,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Obx(
            () => Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: isMobile ? 12 : 20,
              runSpacing: 20,
              children: [
                _EquationItem(
                  label: "Total Assets",
                  amount: ctrl.grandTotalAssets,
                  fmt: fmt,
                  color: Colors.greenAccent,
                  prevAmount: ctrl.comparisonReport.value?.totalAssets,
                ),
                const FaIcon(
                  FontAwesomeIcons.minus,
                  color: Colors.white24,
                  size: 16,
                ),
                _EquationItem(
                  label: "Total Liabilities",
                  amount: ctrl.grandTotalLiabilities,
                  fmt: fmt,
                  color: Colors.redAccent,
                  prevAmount: ctrl.comparisonReport.value?.totalLiabilities,
                ),
                const FaIcon(
                  FontAwesomeIcons.equals,
                  color: Colors.white,
                  size: 16,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "REAL VALUE",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        fmt.format(ctrl.netWorth),
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (ctrl.comparisonReport.value != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last year: ${fmt.format(ctrl.comparisonReport.value!.netWorth)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Builder(
                          builder: (_) {
                            final diff =
                                ctrl.netWorth -
                                ctrl.comparisonReport.value!.netWorth;
                            final isUp = diff >= 0;
                            final deltaColor =
                                isUp
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626);
                            final compact = NumberFormat.compactSimpleCurrency(
                              name: '৳',
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: deltaColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${isUp ? '▲' : '▼'} ${compact.format(diff.abs())} vs FY ${ctrl.comparisonReport.value!.year}',
                                style: TextStyle(
                                  color: deltaColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // Dialogs
  // ───────────────────────────────────────────────
  void _showCloseYearDialog(
    BuildContext context,
    FinancialController ctrl,
    NumberFormat fmt,
  ) {
    final currentYear = DateTime.now().year;
    // Check if already closed for this year
    final alreadyClosed = ctrl.closedYearReports.any(
      (r) => r.year == currentYear,
    );

    Get.defaultDialog(
      title: "Close Financial Year $currentYear",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      content: Column(
        children: [
          if (alreadyClosed)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Year $currentYear is already closed. Closing again will create a second snapshot.",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const Icon(Icons.lock_clock, size: 48, color: Color(0xFF1E293B)),
          const SizedBox(height: 12),
          const Text(
            "This will save a permanent snapshot of the current financial state.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          _DialogSummaryRow("Net Worth", fmt.format(ctrl.netWorth)),
          _DialogSummaryRow("Total Assets", fmt.format(ctrl.grandTotalAssets)),
          _DialogSummaryRow(
            "Total Liabilities",
            fmt.format(ctrl.grandTotalLiabilities),
          ),
          const SizedBox(height: 12),
          Text(
            "You can restore (delete) this snapshot later if needed.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
      confirm: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
        ),
        icon: const Icon(Icons.lock, color: Colors.white, size: 16),
        label: const Text("Close Year", style: TextStyle(color: Colors.white)),
        onPressed: () async {
          Get.back();
          final docId = await ctrl.closeYear(currentYear);
          Get.snackbar(
            "✅ Year Closed",
            "Financial Year $currentYear has been saved successfully.",
            backgroundColor: Colors.green[700],
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
          debugPrint("Closed year saved: $docId");
        },
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }

  void _showClosedYearsSheet(
    BuildContext context,
    FinancialController ctrl,
    NumberFormat fmt,
  ) {
    final compact = NumberFormat.compactSimpleCurrency(name: '৳');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            minChildSize: 0.35,
            builder:
                (_, scrollCtrl) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history_edu,
                              color: Color(0xFF1E293B),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Closed Year Reports",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Obx(
                              () =>
                                  ctrl.comparisonReport.value != null
                                      ? TextButton.icon(
                                        icon: const Icon(Icons.close, size: 14),
                                        label: const Text("Clear Compare"),
                                        onPressed: () {
                                          ctrl.setComparison(null);
                                          Navigator.pop(context);
                                        },
                                      )
                                      : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Obx(
                          () => ListView.builder(
                            controller: scrollCtrl,
                            itemCount: ctrl.closedYearReports.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (_, i) {
                              final r = ctrl.closedYearReports[i];
                              final isSelected =
                                  ctrl.comparisonReport.value?.id == r.id;
                              final closedDate = DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(r.closedAt);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? const Color(0xFF2563EB)
                                            : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color:
                                      isSelected
                                          ? const Color(0xFFEFF6FF)
                                          : Colors.white,
                                ),
                                child: ExpansionTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1E293B,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${r.year}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    "FY ${r.year} — ${compact.format(r.netWorth)} net worth",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Closed on $closedDate",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  trailing:
                                      isSelected
                                          ? const Icon(
                                            Icons.compare_arrows,
                                            color: Color(0xFF2563EB),
                                          )
                                          : null,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        children: [
                                          _SheetStatRow(
                                            "Total Assets",
                                            fmt.format(r.totalAssets),
                                            color: Colors.green[700],
                                          ),
                                          _SheetStatRow(
                                            "Total Liabilities",
                                            fmt.format(r.totalLiabilities),
                                            color: Colors.red[700],
                                          ),
                                          _SheetStatRow(
                                            "Net Worth",
                                            fmt.format(r.netWorth),
                                            isBold: true,
                                            color: const Color(0xFF2563EB),
                                          ),
                                          const Divider(height: 20),
                                          _SheetStatRow(
                                            "Cash",
                                            fmt.format(r.cash),
                                          ),
                                          _SheetStatRow(
                                            "Stock",
                                            fmt.format(r.stockValuation),
                                          ),
                                          _SheetStatRow(
                                            "Shipments",
                                            fmt.format(r.shipmentValuation),
                                          ),
                                          _SheetStatRow(
                                            "Receivables",
                                            fmt.format(r.debtorReceivables),
                                          ),
                                          _SheetStatRow(
                                            "Staff Loans",
                                            fmt.format(r.employeeDebt),
                                          ),
                                          _SheetStatRow(
                                            "Fixed Assets",
                                            fmt.format(r.fixedAssets),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              // Compare toggle
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  icon: Icon(
                                                    isSelected
                                                        ? Icons.compare_arrows
                                                        : Icons.compare,
                                                    size: 16,
                                                    color:
                                                        isSelected
                                                            ? Colors.grey
                                                            : const Color(
                                                              0xFF2563EB,
                                                            ),
                                                  ),
                                                  label: Text(
                                                    isSelected
                                                        ? "Clear Compare"
                                                        : "Compare with Live",
                                                    style: TextStyle(
                                                      color:
                                                          isSelected
                                                              ? Colors.grey
                                                              : const Color(
                                                                0xFF2563EB,
                                                              ),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        side: BorderSide(
                                                          color:
                                                              isSelected
                                                                  ? Colors
                                                                      .grey
                                                                      .shade300
                                                                  : const Color(
                                                                    0xFF2563EB,
                                                                  ),
                                                        ),
                                                      ),
                                                  onPressed: () {
                                                    ctrl.setComparison(
                                                      isSelected ? null : r,
                                                    );
                                                    Navigator.pop(context);
                                                    Get.snackbar(
                                                      isSelected
                                                          ? "Compare Cleared"
                                                          : "📊 Comparing with FY ${r.year}",
                                                      isSelected
                                                          ? "Comparison mode off."
                                                          : "Differences are now shown on all metrics.",
                                                      snackPosition:
                                                          SnackPosition.BOTTOM,
                                                      backgroundColor:
                                                          isSelected
                                                              ? Colors.grey[700]
                                                              : const Color(
                                                                0xFF1E293B,
                                                              ),
                                                      colorText: Colors.white,
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Print this year's archived report
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.print_outlined,
                                                  size: 16,
                                                  color: Colors.blueGrey,
                                                ),
                                                label: const Text(
                                                  "Print",
                                                  style: TextStyle(
                                                    color: Colors.blueGrey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  // printSnapshot = r means the PDF uses
                                                  // saved snapshot values, not live data
                                                  ctrl.generateAndPrintPDF(
                                                    printSnapshot: r,
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 8),
                                              // Restore (delete) button
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.restore,
                                                  size: 16,
                                                  color: Colors.deepOrange,
                                                ),
                                                label: const Text(
                                                  "Restore",
                                                  style: TextStyle(
                                                    color: Colors.deepOrange,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: Colors.deepOrange,
                                                  ),
                                                ),
                                                onPressed:
                                                    () => _confirmRestore(
                                                      context,
                                                      ctrl,
                                                      r,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _confirmRestore(
    BuildContext context,
    FinancialController ctrl,
    ClosedYearReport report,
  ) {
    Get.defaultDialog(
      title: "Restore FY ${report.year}?",
      content: Column(
        children: [
          const Icon(Icons.restore, size: 40, color: Colors.deepOrange),
          const SizedBox(height: 12),
          Text(
            "This will permanently delete the FY ${report.year} snapshot. "
            "The live data is not affected — only the saved record is removed.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      confirm: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
        label: const Text(
          "Yes, Restore",
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () async {
          Get.back();
          Get.back(); // close bottom sheet too
          await ctrl.restoreClosedYear(report.id);
          Get.snackbar(
            "✅ Snapshot Removed",
            "FY ${report.year} record has been deleted.",
            backgroundColor: Colors.deepOrange[700],
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }

  void _showAddAssetDialog(BuildContext context, FinancialController ctrl) {
    final nameC = TextEditingController();
    final valC = TextEditingController();
    final catC = TextEditingController();
    Get.defaultDialog(
      title: "Add Business Asset",
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Item Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: valC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Value",
              prefixText: "৳ ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: catC,
            decoration: const InputDecoration(
              labelText: "Category",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          ctrl.addAsset(nameC.text, double.tryParse(valC.text) ?? 0, catC.text);
          Get.back();
        },
        child: const Text("Save"),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, FinancialController ctrl) {
    final titleC = TextEditingController();
    final amountC = TextEditingController();
    Get.defaultDialog(
      title: "Add Monthly Cost",
      content: Column(
        children: [
          TextField(
            controller: titleC,
            decoration: const InputDecoration(
              labelText: "Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount",
              prefixText: "৳ ",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          ctrl.addRecurringExpense(
            titleC.text,
            double.tryParse(amountC.text) ?? 0,
            "Monthly",
          );
          Get.back();
        },
        child: const Text("Save"),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHIMMER SKELETON
// ─────────────────────────────────────────────────────────────
class _ShimmerSkeleton extends StatelessWidget {
  final bool isMobile;
  final bool isDesktop;
  const _ShimmerSkeleton({required this.isMobile, required this.isDesktop});

  Widget _box(double w, double h, {double radius = 8}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
        child: Column(
          children: [
            // KPI row
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: _box(double.infinity, 100)),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Two-column cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _box(double.infinity, 200),
                      const SizedBox(height: 16),
                      _box(double.infinity, 280),
                    ],
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _box(double.infinity, 180),
                        const SizedBox(height: 16),
                        _box(double.infinity, 240),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _box(double.infinity, 100, radius: 12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPARISON BANNER
// ─────────────────────────────────────────────────────────────
class _ComparisonBanner extends StatelessWidget {
  final int year;
  final VoidCallback onClear;
  const _ComparisonBanner({required this.year, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFF2563EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Comparing with FY $year — deltas shown on each metric",
              style: const TextStyle(
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text(
              "Clear",
              style: TextStyle(color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DELTA BADGE
// ─────────────────────────────────────────────────────────────
class DeltaBadge extends StatelessWidget {
  final double current;
  final double prev;
  final String label;
  final bool invertColor;

  const DeltaBadge({
    super.key,
    required this.current,
    required this.prev,
    required this.label,
    this.invertColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final diff = current - prev;
    final isUp = diff >= 0;
    final isGood = invertColor ? !isUp : isUp;
    final color = isGood ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final compact = NumberFormat.compactSimpleCurrency(name: '৳');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "${isUp ? '▲' : '▼'} ${compact.format(diff.abs())} $label",
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label;
  final String subLabel;
  final double amount;
  final dynamic icon;
  final Color color;
  final NumberFormat formatter;
  final bool isHighlight;
  final double? prevAmount;
  final bool invertDelta;

  const _SummaryTile({
    required this.label,
    required this.subLabel,
    required this.amount,
    required this.icon,
    required this.color,
    required this.formatter,
    this.isHighlight = false,
    this.prevAmount,
    this.invertDelta = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = prevAmount != null;
    final diff = hasPrev ? amount - prevAmount! : 0.0;
    final isUp = diff >= 0;
    final isGood = invertDelta ? !isUp : isUp;
    final deltaColor =
        isGood ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final compact = NumberFormat.compactSimpleCurrency(name: '৳');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? color.withOpacity(0.5) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatter.format(amount),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasPrev) ...[
            const SizedBox(height: 8),
            // ── Divider between current and prior ──
            Container(height: 0.5, color: Colors.grey[200]),
            const SizedBox(height: 8),
            // ── Actual prior year value ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last year',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatter.format(prevAmount!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // ── Delta badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: deltaColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 10,
                    color: deltaColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${compact.format(diff.abs())} vs last year',
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErpSectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _ErpSectionHeader({required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey[800],
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErpCard extends StatelessWidget {
  final String title;
  final dynamic icon;
  final Color accentColor;
  final Widget child;
  final Widget? action;
  const _ErpCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                FaIcon(icon, color: accentColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(20.0), child: child),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat fmt;
  final bool isBold;
  final Color? color;
  final double? prevAmount;
  final bool invertDelta;

  const _StatRow(
    this.label,
    this.amount,
    this.fmt, {
    this.isBold = false,
    this.color,
    this.prevAmount,
    this.invertDelta = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = prevAmount != null;
    final diff = hasPrev ? amount - prevAmount! : 0.0;
    final isUp = diff >= 0;
    final isGood = invertDelta ? !isUp : isUp;
    final deltaColor =
        isGood ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final compact = NumberFormat.compactSimpleCurrency(name: '৳');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: isBold ? 15 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Current value + delta chip stacked on the right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(amount),
                    style: TextStyle(
                      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                      color: color ?? Colors.black87,
                      fontSize: isBold ? 16 : 14,
                    ),
                  ),
                  if (hasPrev) ...[
                    const SizedBox(height: 3),
                    // ── Actual prior year value ──
                    Text(
                      'Last year: ${fmt.format(prevAmount!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // ── Delta badge ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: deltaColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isUp ? '▲' : '▼'} ${compact.format(diff.abs())}',
                        style: TextStyle(
                          color: deltaColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualItemRow extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat compactFmt;
  final VoidCallback onDelete;
  const _ManualItemRow({
    required this.label,
    required this.amount,
    required this.compactFmt,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            compactFmt.format(amount),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _EquationItem extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat fmt;
  final Color color;
  final double? prevAmount;
  const _EquationItem({
    required this.label,
    required this.amount,
    required this.fmt,
    required this.color,
    this.prevAmount,
  });
  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactSimpleCurrency(name: '৳');
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(amount),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (prevAmount != null) ...[
          const SizedBox(height: 3),
          // Clearly show the actual prior year value
          Text(
            'Last yr: ${compact.format(prevAmount!)}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _DialogSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _DialogSummaryRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SheetStatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  const _SheetStatRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
