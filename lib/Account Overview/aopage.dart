// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

    // COLORS
    const Color bgSlate = Color(0xFFF8FAFC);
    const Color darkHeader = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgSlate,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "EXECUTIVE SUMMARY",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              "Financial Health Report",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: darkHeader,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: "Print Report",
            onPressed: () => controller.generateAndPrintPDF(),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: "Refresh Data",
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
              // 1. BIG NUMBERS (KPI)
              // ===============================================
              _buildTopKPIs(controller, currency),

              const SizedBox(height: 24),

              // ===============================================
              // 2. RESPONSIVE SPLIT VIEW
              // ===============================================
              LayoutBuilder(
                builder: (context, constraints) {
                  // If screen is wide (Tablet/PC), show side-by-side
                  if (constraints.maxWidth > 850) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildAssetsColumn(
                            controller,
                            currency,
                            compactCurrency,
                            context,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildLiabilitiesColumn(
                            controller,
                            currency,
                            context,
                          ),
                        ),
                      ],
                    );
                  }
                  // If screen is narrow (Mobile), show vertical stack
                  return Column(
                    children: [
                      _buildAssetsColumn(
                        controller,
                        currency,
                        compactCurrency,
                        context,
                      ),
                      const SizedBox(height: 24),
                      _buildLiabilitiesColumn(controller, currency, context),
                    ],
                  );
                },
              ),

              const SizedBox(height: 30),

              // ===============================================
              // 3. FINAL EQUATION FOOTER
              // ===============================================
              _buildFinalEquation(controller, currency),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopKPIs(FinancialController ctrl, NumberFormat fmt) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Grid Logic
        int crossAxisCount = constraints.maxWidth > 600 ? 3 : 1;

        // FIX: Lowered ratio from 3.0 to 2.4 to give cards more height
        double ratio = constraints.maxWidth > 600 ? 2.2 : 2.4;

        return Obx(() {
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: ratio,
            children: [
              _SummaryTile(
                label: "Total Business Value",
                subLabel: "(What You Own)",
                amount: ctrl.grandTotalAssets,
                icon: FontAwesomeIcons.buildingColumns,
                color: const Color(0xFF059669),
                formatter: fmt,
              ),
              _SummaryTile(
                label: "Total Debt",
                subLabel: "(What You Owe)",
                amount: ctrl.grandTotalLiabilities,
                icon: FontAwesomeIcons.fileInvoiceDollar,
                color: const Color(0xFFDC2626),
                formatter: fmt,
              ),
              _SummaryTile(
                label: "Real Profit / Equity",
                subLabel: "(Your Actual Money)",
                amount: ctrl.netWorth,
                icon: FontAwesomeIcons.chartLine,
                color: const Color(0xFF2563EB),
                formatter: fmt,
                isHighlight: true,
              ),
            ],
          );
        });
      },
    );
  }

  // ===========================================================================
  // SECTION 2: ASSETS (WHAT YOU HAVE)
  // ===========================================================================
  Widget _buildAssetsColumn(
    FinancialController ctrl,
    NumberFormat fmt,
    NumberFormat compact,
    BuildContext context,
  ) {
    final cashCtrl = Get.find<CashDrawerController>();

    return Column(
      children: [
        // 1. CASH ACCOUNTS
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
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. INVENTORY & RECEIVABLES
        _ErpCard(
          title: "Inventory & Pending Collections",
          icon: FontAwesomeIcons.boxesStacked,
          accentColor: Colors.blueGrey,
          action: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blueGrey),
            tooltip: "Add Manual Asset (Furniture/PC)",
            onPressed: () => _showAddAssetDialog(context, ctrl),
          ),
          child: Obx(
            () => Column(
              children: [
                _StatRow(
                  "Stock/Inventory Value",
                  ctrl.totalStockValuation,
                  fmt,
                  helpText: "Total purchase price of items in shop",
                ),
                _StatRow(
                  "Incoming Shipments",
                  ctrl.totalShipmentValuation,
                  fmt,
                  helpText: "Products currently on the way",
                ),
                _StatRow(
                  "Customers Owe You",
                  ctrl.totalDebtorReceivables,
                  fmt,
                  color: Colors.orange[800],
                  helpText: "Due payments from customers",
                ),
                _StatRow("Loans Given to Staff", ctrl.totalEmployeeDebt, fmt),

                const Divider(height: 20),

                // Manual Fixed Assets
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 3: LIABILITIES (WHAT YOU OWE)
  // ===========================================================================
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

        // 1. PAYABLES
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
                  helpText: "Money you owe to vendors",
                ),
                _StatRow(
                  "To Pay Customers",
                  ctrl.totalDebtorPayable,
                  fmt,
                  helpText: "Returns or advanced payments held",
                ),

                const Divider(height: 24),
                _StatRow(
                  "TOTAL PAYABLES",
                  (ctrl.totalVendorDue + ctrl.totalDebtorPayable),
                  fmt,
                  isBold: true,
                  color: Colors.red[900],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. MONTHLY EXPENSES
        _ErpCard(
          title: "Monthly Fixed Costs",
          icon: FontAwesomeIcons.calendarCheck,
          accentColor: Colors.orange[800]!,
          action: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
            tooltip: "Add Monthly Cost (Salary/Rent)",
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
                    compactFmt: fmt, // Using full format here
                    onDelete: () => ctrl.deleteRecurringExpense(item.id!),
                  ),
                ),

                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.all(8),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 4: FINAL CALCULATION
  // ===========================================================================
  Widget _buildFinalEquation(FinancialController ctrl, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
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
              spacing: 20,
              runSpacing: 20,
              children: [
                _EquationItem(
                  label: "Total Assets",
                  amount: ctrl.grandTotalAssets,
                  fmt: fmt,
                  color: Colors.greenAccent,
                ),
                const Icon(
                  FontAwesomeIcons.minus,
                  color: Colors.white24,
                  size: 16,
                ),
                _EquationItem(
                  label: "Total Liabilities",
                  amount: ctrl.grandTotalLiabilities,
                  fmt: fmt,
                  color: Colors.redAccent,
                ),
                const Icon(
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

  // ===========================================================================
  // WIDGET HELPERS
  // ===========================================================================

  // Dialogs remain largely the same logic, just styled cleaner
  void _showAddAssetDialog(BuildContext context, FinancialController ctrl) {
    // ... same logic as before, just cleaner UI if needed ...
    final nameC = TextEditingController();
    final valC = TextEditingController();
    final catC = TextEditingController();
    Get.defaultDialog(
      title: "Add Business Asset",
      contentPadding: const EdgeInsets.all(20),
      radius: 8,
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Item Name",
              hintText: "e.g. Shop Laptop",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: valC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Current Value",
              prefixText: "৳ ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: catC,
            decoration: const InputDecoration(
              labelText: "Category",
              hintText: "e.g. Electronics",
              border: OutlineInputBorder(),
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
        child: const Text("Save Record", style: TextStyle(color: Colors.white)),
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
      title: "Add Monthly Cost",
      contentPadding: const EdgeInsets.all(20),
      radius: 8,
      content: Column(
        children: [
          TextField(
            controller: titleC,
            decoration: const InputDecoration(
              labelText: "Expense Name",
              hintText: "e.g. Shop Rent",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Monthly Cost",
              prefixText: "৳ ",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
        onPressed:
            () => ctrl.addRecurringExpense(
              titleC.text,
              double.tryParse(amountC.text) ?? 0,
              "Monthly",
            ),
        child: const Text("Save Cost", style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE COMPONENTS (MODULAR & CLEAN)
// -----------------------------------------------------------------------------

class _SummaryTile extends StatelessWidget {
  final String label;
  final String subLabel;
  final double amount;
  final IconData icon;
  final Color color;
  final NumberFormat formatter;
  final bool isHighlight;

  const _SummaryTile({
    required this.label,
    required this.subLabel,
    required this.amount,
    required this.icon,
    required this.color,
    required this.formatter,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // FIX: Reduced padding from 20 to 14 to save space
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        // FIX: Distribute space evenly instead of center
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Reduced padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10, // Reduced font
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Amount (Expanded allows it to take remaining height)
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                formatter.format(amount),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // Footer
          Text(
            subLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
        Text(
          title,
          style: TextStyle(
            color: Colors.blueGrey[700],
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ErpCard extends StatelessWidget {
  final String title;
  final IconData icon;
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
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
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
  final String? helpText;

  const _StatRow(
    this.label,
    this.amount,
    this.fmt, {
    this.isBold = false,
    this.color,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
              ),
              if (helpText != null)
                Text(
                  helpText!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
            ],
          ),
          Text(
            fmt.format(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? Colors.black87,
              fontSize: isBold ? 16 : 14,
            ),
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
          Icon(Icons.circle, size: 6, color: Colors.grey[300]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Text(
            compactFmt.format(amount),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.close, size: 16, color: Colors.red[300]),
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

  const _EquationItem({
    required this.label,
    required this.amount,
    required this.fmt,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          fmt.format(amount),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
