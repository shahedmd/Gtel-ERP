import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// CONTROLLERS
import 'package:gtel_erp/Account%20Overview/controllerao.dart';
import 'package:gtel_erp/Cash/controller.dart';

class FinancialOverviewPage extends StatelessWidget {
  const FinancialOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FinancialController());

    // FORMATTERS
    final currency = NumberFormat.currency(
      locale: 'en_BD',
      symbol: '৳',
      decimalDigits: 0,
    );
    final compactCurrency = NumberFormat.compactSimpleCurrency(name: '৳');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate-100
      appBar: AppBar(
        title: const Text(
          "FINANCIAL OVERVIEW",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0F172A), // Slate-900
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: "Download PDF Report",
            onPressed: () => controller.generateAndPrintPDF(),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: "Sync Data",
            onPressed: () => controller.refreshExternalData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshExternalData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===============================================
              // 1. KPI SUMMARY TILES
              // ===============================================
              Obx(
                () => Row(
                  children: [
                    _SummaryTile(
                      title: "TOTAL ASSETS",
                      amount: controller.grandTotalAssets,
                      icon: Icons.account_balance,
                      color: const Color(0xFF0F766E), // Teal-700
                      formatter: currency,
                    ),
                    const SizedBox(width: 12),
                    _SummaryTile(
                      title: "TOTAL LIABILITIES",
                      amount: controller.grandTotalLiabilities,
                      icon: Icons.money_off,
                      color: const Color(0xFFB91C1C), // Red-700
                      formatter: currency,
                    ),
                    const SizedBox(width: 12),
                    _SummaryTile(
                      title: "NET WORTH",
                      amount: controller.netWorth,
                      icon: Icons.show_chart,
                      color: const Color(0xFF1E3A8A), // Blue-900
                      formatter: currency,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===============================================
              // 2. MAIN SPLIT VIEW (Left: Assets, Right: Liabilities)
              // ===============================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: ASSETS
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildCashBreakdown(controller, currency),
                        const SizedBox(height: 20),
                        _buildAssetsBreakdown(
                          controller,
                          currency,
                          compactCurrency,
                          context,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // RIGHT: LIABILITIES
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildLiabilitiesSection(controller, currency, context),
                        const SizedBox(height: 20),
                        _buildPayrollSection(controller, currency, context),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ===============================================
              // 3. FINANCIAL BREAKDOWN FOOTER
              // ===============================================
              _buildFinancialFooter(controller, currency),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION BUILDERS
  // ===========================================================================

  Widget _buildCashBreakdown(FinancialController ctrl, NumberFormat fmt) {
    final cashCtrl = Get.find<CashDrawerController>();
    return _ErpCard(
      title: "Liquid Assets (Cash)",
      icon: Icons.payments,
      color: Colors.teal,
      child: Obx(
        () => Column(
          children: [
            _StatRow("Cash In Hand", cashCtrl.netCash.value, fmt),
            _StatRow("Bank Balance", cashCtrl.netBank.value, fmt),
            _StatRow("Bkash Balance", cashCtrl.netBkash.value, fmt),
            _StatRow("Nagad Balance", cashCtrl.netNagad.value, fmt),
            const Divider(),
            _StatRow(
              "TOTAL LIQUID",
              ctrl.totalCash,
              fmt,
              isBold: true,
              color: Colors.teal[800],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsBreakdown(
    FinancialController ctrl,
    NumberFormat fmt,
    NumberFormat compact,
    BuildContext context,
  ) {
    return _ErpCard(
      title: "Company Assets",
      icon: Icons.domain,
      color: Colors.blueGrey,
      action: InkWell(
        onTap: () => _showAddAssetDialog(context, ctrl),
        child: const Icon(Icons.add_circle, color: Colors.blueGrey, size: 24),
      ),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Automated
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _StatRow(
                    "Stock Value",
                    ctrl.totalStockValuation,
                    fmt,
                    icon: Icons.store,
                  ),
                  _StatRow(
                    "Shipments (On Way)",
                    ctrl.totalShipmentValuation,
                    fmt,
                    icon: Icons.local_shipping,
                  ),
                  _StatRow(
                    "Receivables (Debtors)",
                    ctrl.totalDebtorReceivables,
                    fmt,
                    icon: Icons.arrow_circle_down,
                  ),
                  _StatRow(
                    "Staff Loans",
                    ctrl.totalEmployeeDebt,
                    fmt,
                    icon: Icons.badge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Manual
            const Text(
              "FIXED ASSETS (MANUAL)",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            if (ctrl.fixedAssets.isEmpty)
              const Text(
                "No fixed assets added.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

            ...ctrl.fixedAssets.map(
              (asset) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        asset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      compact.format(asset.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => ctrl.deleteAsset(asset.id!),
                      child: const Icon(
                        Icons.remove_circle,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(thickness: 1.5),
            _StatRow(
              "TOTAL ASSETS",
              ctrl.grandTotalAssets,
              fmt,
              isBold: true,
              color: Colors.blueGrey[900],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiabilitiesSection(
    FinancialController ctrl,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return _ErpCard(
      title: "Liabilities & Payables",
      icon: Icons.money_off,
      color: Colors.red[800]!,
      child: Obx(
        () => Column(
          children: [
            _StatRow(
              "Vendor Payables",
              ctrl.totalVendorDue,
              fmt,
              icon: Icons.store,
              color: Colors.red[900],
            ),
            _StatRow(
              "Debtor Payables",
              ctrl.totalDebtorPayable,
              fmt,
              icon: Icons.person_off,
              color: Colors.red[900],
            ),

            const Divider(),
            _StatRow(
              "TOTAL DEBT",
              (ctrl.totalVendorDue + ctrl.totalDebtorPayable),
              fmt,
              isBold: true,
              color: Colors.red[900],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollSection(
    FinancialController ctrl,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return _ErpCard(
      title: "Monthly Payroll & Expenses",
      icon: Icons.groups,
      color: Colors.orange[800]!,
      action: InkWell(
        onTap: () => _showAddExpenseDialog(context, ctrl),
        child: Icon(Icons.add_circle, color: Colors.orange[800], size: 24),
      ),
      child: Obx(
        () => Column(
          children: [
            if (ctrl.recurringExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "No payroll setup.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            ...ctrl.recurringExpenses.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      fmt.format(item.monthlyAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => ctrl.deleteRecurringExpense(item.id!),
                      child: const Icon(
                        Icons.remove_circle,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: _StatRow(
                "MONTHLY BURN",
                ctrl.totalMonthlyPayroll,
                fmt,
                isBold: true,
                color: Colors.orange[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialFooter(FinancialController ctrl, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark Slate
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "COMPANY NET WORTH CALCULATION",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _FooterItem(
                  label: "Grand Total Assets",
                  amount: ctrl.grandTotalAssets,
                  fmt: fmt,
                  color: Colors.greenAccent,
                ),
                const Icon(Icons.remove, color: Colors.white24),
                _FooterItem(
                  label: "Grand Total Liabilities",
                  amount: ctrl.grandTotalLiabilities,
                  fmt: fmt,
                  color: Colors.redAccent,
                ),
                const Icon(Icons.drag_handle, color: Colors.white24),
                _FooterItem(
                  label: "NET WORTH",
                  amount: ctrl.netWorth,
                  fmt: fmt,
                  color: Colors.white,
                  isLarge: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER DIALOGS
  // ===========================================================================

  void _showAddAssetDialog(BuildContext context, FinancialController ctrl) {
    final nameC = TextEditingController();
    final valC = TextEditingController();
    final catC = TextEditingController();

    Get.defaultDialog(
      title: "Add Fixed Asset",
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Asset Name",
              hintText: "e.g. Shop PC",
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: catC,
            decoration: const InputDecoration(
              labelText: "Category",
              hintText: "e.g. Electronics",
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: valC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Value",
              prefixText: "৳ ",
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
        ),
        onPressed:
            () => ctrl.addAsset(
              nameC.text,
              double.tryParse(valC.text) ?? 0,
              catC.text,
            ),
        child: const Text("Save Asset", style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, FinancialController ctrl) {
    final titleC = TextEditingController();
    final amountC = TextEditingController();

    Get.defaultDialog(
      title: "Add Payroll/Expense",
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        children: [
          TextField(
            controller: titleC,
            decoration: const InputDecoration(
              labelText: "Title",
              hintText: "e.g. Staff Salary",
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Monthly Amount",
              prefixText: "৳ ",
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
        onPressed:
            () => ctrl.addRecurringExpense(
              titleC.text,
              double.tryParse(amountC.text) ?? 0,
              "Monthly",
            ),
        child: const Text(
          "Save Expense",
          style: TextStyle(color: Colors.white),
        ),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }
}

// ===========================================================================
// SMALL WIDGETS
// ===========================================================================

class _SummaryTile extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final NumberFormat formatter;

  const _SummaryTile({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatter.format(amount),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErpCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? action;

  const _ErpCard({
    required this.title,
    required this.icon,
    required this.color,
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16.0), child: child),
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
  final IconData? icon;

  const _StatRow(
    this.label,
    this.amount,
    this.fmt, {
    this.isBold = false,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: Colors.grey[800],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Text(
            fmt.format(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black87,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat fmt;
  final Color color;
  final bool isLarge;

  const _FooterItem({
    required this.label,
    required this.amount,
    required this.fmt,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(amount),
          style: TextStyle(
            color: color,
            fontSize: isLarge ? 24 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
