import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/controllerao.dart';
import 'package:intl/intl.dart';
// import 'package:gtel_erp/controllers/financial_controller.dart';

class AppColors {
  static const Color primary = Color(0xFF2C3E50);
  static const Color secondary = Color(0xFF34495E);
  static const Color accent = Color(0xFF3498DB);
  static const Color success = Color(0xFF27AE60);
  static const Color danger = Color(0xFFC0392B);
  static const Color bg = Color(0xFFECF0F1);
  static const Color cardBg = Colors.white;
}

class FinancialOverviewPage extends StatelessWidget {
  const FinancialOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FinancialController());

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          "FINANCIAL OVERVIEW",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.print),
            tooltip: "Print Report",
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP SUMMARY CARDS
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => _SummaryCard(
                      title: "NET WORTH",
                      amount: controller.netWorth.value,
                      color: AppColors.primary,
                      icon: Icons.account_balance,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(
                    () => _SummaryCard(
                      title: "TOTAL ASSETS",
                      amount: controller.totalAssets.value,
                      color: AppColors.success,
                      icon: Icons.trending_up,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(
                    () => _SummaryCard(
                      title: "TOTAL LIABILITIES",
                      amount:
                          controller.totalVendorDue.value, // Just external debt
                      color: AppColors.danger,
                      icon: Icons.trending_down,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. MAIN SPLIT VIEW (ASSETS LEFT, LIABILITIES/PAYROLL RIGHT)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: ASSETS
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // Liquid Cash Section
                      _LiquidCashSection(controller: controller),
                      const SizedBox(height: 16),
                      // Fixed Assets Section (Editable)
                      _FixedAssetsSection(controller: controller),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // RIGHT COLUMN: LIABILITIES & PAYROLL
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      // Payables Section
                      _LiabilitiesSection(controller: controller),
                      const SizedBox(height: 16),
                      // Payroll Section (Editable)
                      _PayrollSection(controller: controller),
                    ],
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

// --- WIDGETS ---

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 30),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            NumberFormat.simpleCurrency(name: 'BDT').format(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidCashSection extends StatelessWidget {
  final FinancialController controller;
  const _LiquidCashSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: "Liquid Assets (Cash)",
      icon: Icons.attach_money,
      color: AppColors.success,
      child: Column(
        children: [
          Obx(() => _StatRow("Cash In Hand", controller.cashInHand.value)),
          Obx(() => _StatRow("Bank Balance", controller.cashInBank.value)),
          Obx(() => _StatRow("Bkash Balance", controller.cashInBkash.value)),
          Obx(() => _StatRow("Nagad Balance", controller.cashInNagad.value)),
          const Divider(),
          Obx(
            () => _StatRow(
              "Receivables (Debtors)",
              controller.totalDebtorReceivable.value,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedAssetsSection extends StatelessWidget {
  final FinancialController controller;
  const _FixedAssetsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: "Fixed Assets",
      icon: Icons.domain,
      color: AppColors.secondary,
      action: IconButton(
        icon: const Icon(Icons.add_circle, color: AppColors.accent),
        onPressed: () => _showAddAssetDialog(context, controller),
      ),
      child: Obx(() {
        if (controller.fixedAssets.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("No Fixed Assets Recorded"),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.fixedAssets.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final asset = controller.fixedAssets[index];
            return ListTile(
              title: Text(
                asset.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                asset.category,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    NumberFormat.compactSimpleCurrency(
                      name: '৳',
                    ).format(asset.value),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => controller.deleteAsset(asset.id!),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  void _showAddAssetDialog(BuildContext context, FinancialController ctrl) {
    final nameC = TextEditingController();
    final valueC = TextEditingController();
    final catC = TextEditingController();

    Get.defaultDialog(
      title: "Add Fixed Asset",
      content: Column(
        children: [
          TextField(
            controller: nameC,
            decoration: const InputDecoration(
              labelText: "Asset Name (e.g. Laptop)",
            ),
          ),
          TextField(
            controller: catC,
            decoration: const InputDecoration(
              labelText: "Category (e.g. Equipment)",
            ),
          ),
          TextField(
            controller: valueC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Value/Cost"),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          ctrl.addAsset(
            nameC.text,
            double.tryParse(valueC.text) ?? 0,
            catC.text,
          );
        },
        child: const Text("Save Asset"),
      ),
    );
  }
}

class _LiabilitiesSection extends StatelessWidget {
  final FinancialController controller;
  const _LiabilitiesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: "Liabilities & Dues",
      icon: Icons.money_off,
      color: AppColors.danger,
      child: Column(
        children: [
          Obx(
            () => _StatRow(
              "Vendor Dues (Payable)",
              controller.totalVendorDue.value,
              isNegative: true,
            ),
          ),
          // You can add more placeholder liabilities here
          _StatRow("Loans Payable", 0.0, isNegative: true),
        ],
      ),
    );
  }
}

class _PayrollSection extends StatelessWidget {
  final FinancialController controller;
  const _PayrollSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: "Monthly Payroll & Expenses",
      icon: Icons.people,
      color: Colors.orange[800]!,
      action: IconButton(
        icon: const Icon(Icons.add_circle, color: AppColors.accent),
        onPressed: () => _showAddPayrollDialog(context, controller),
      ),
      child: Column(
        children: [
          Obx(() {
            if (controller.payrollItems.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No Payroll Setup"),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.payrollItems.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = controller.payrollItems[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text("Monthly ${item.type}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        NumberFormat.compactSimpleCurrency(
                          name: '৳',
                        ).format(item.monthlyAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () => controller.deletePayroll(item.id!),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
          const Divider(thickness: 2),
          Obx(
            () => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TOTAL MONTHLY COMMITMENT:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    NumberFormat.simpleCurrency(
                      name: 'BDT',
                    ).format(controller.totalMonthlyPayroll.value),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
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

  void _showAddPayrollDialog(BuildContext context, FinancialController ctrl) {
    final titleC = TextEditingController();
    final amountC = TextEditingController();

    Get.defaultDialog(
      title: "Add Recurring Expense",
      content: Column(
        children: [
          TextField(
            controller: titleC,
            decoration: const InputDecoration(
              labelText: "Title (e.g. Shop Rent)",
            ),
          ),
          TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Monthly Amount"),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          ctrl.addPayrollItem(
            titleC.text,
            double.tryParse(amountC.text) ?? 0,
            'Expense',
          );
        },
        child: const Text("Save Expense"),
      ),
    );
  }
}

// --- HELPER UI COMPONENTS ---

class _SectionContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? action;

  const _SectionContainer({
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
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
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final bool isNegative;

  const _StatRow(
    this.label,
    this.amount, {
    this.isBold = false,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            NumberFormat.simpleCurrency(name: 'BDT').format(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? AppColors.danger : AppColors.primary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
