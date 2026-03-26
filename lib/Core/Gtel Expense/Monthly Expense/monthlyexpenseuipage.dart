import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Monthly%20Expense/montlyexpensecontroller.dart';
import 'package:intl/intl.dart';
class MonthlyExpensesPage extends StatelessWidget {
  MonthlyExpensesPage({super.key});

  final MonthlyExpensesController controller = Get.put(
    MonthlyExpensesController(),
  );

  // Professional Theme Colors (Sync with entire ERP)
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildGrandTotalCard(isMobile),
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 12 : 24,
                0,
                isMobile ? 12 : 24,
                24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMobile) _buildDesktopTableHeader(),
                  if (!isMobile)
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  Expanded(
                    child: Obx(() {
                      if (controller.monthlyList.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(isMobile ? 12 : 0),
                        itemCount: controller.monthlyList.length,
                        itemBuilder: (context, index) {
                          final monthData = controller.monthlyList[index];
                          return isMobile
                              ? _buildMobileCard(context, monthData)
                              : _buildDesktopRow(context, monthData);
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: darkSlate, size: 24),
          const SizedBox(width: 10),
          const Text(
            "Monthly Expense Analytics",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: darkSlate,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: darkSlate),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      actions: [
        IconButton(
          onPressed: () => controller.fetchMonthlyExpenses(),
          icon: const Icon(Icons.refresh, color: textMuted),
          tooltip: "Refresh Data",
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // --- TOP STAT CARD (Lifetime/Grand Total) ---
  Widget _buildGrandTotalCard(bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 24),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              FontAwesomeIcons.chartLine,
              color: activeAccent,
              size: isMobile ? 20 : 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AGGREGATE EXPENDITURE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Lifetime Total across all months",
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          Obx(
            () => Text(
              "৳ ${controller.grandTotalAllMonths.value.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.w800,
                color: darkSlate,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (TABLE)
  // ==========================================
  Widget _buildDesktopTableHeader() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: _headerText("BILLING MONTH")),
          Expanded(flex: 2, child: _headerText("DAYS LOGGED")),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: _headerText("TOTAL EXPENDITURE"),
            ),
          ),
          const SizedBox(width: 100), // Actions space
        ],
      ),
    );
  }

  Widget _headerText(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      color: textMuted,
      fontSize: 11,
      letterSpacing: 0.5,
    ),
  );

  Widget _buildDesktopRow(BuildContext context, dynamic month) {
    return InkWell(
      onTap: () => _showMonthlyDetails(context, month),
      hoverColor: const Color(0xFFF8FAFC),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18, color: textMuted),
                  const SizedBox(width: 10),
                  Text(
                    month.monthKey,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: darkSlate,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${month.items.length} Days",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                "৳ ${month.total.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: activeAccent,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.filePdf,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    tooltip: "Download PDF",
                    splashRadius: 20,
                    onPressed:
                        () => controller.generateMonthlyPDF(month.monthKey),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT (CARDS)
  // ==========================================
  Widget _buildMobileCard(BuildContext context, dynamic month) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showMonthlyDetails(context, month),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        month.monthKey,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: darkSlate,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.filePdf,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed:
                        () => controller.generateMonthlyPDF(month.monthKey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Days Logged",
                        style: TextStyle(
                          fontSize: 10,
                          color: textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${month.items.length}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: darkSlate,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(
                          fontSize: 10,
                          color: textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "৳ ${month.total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: activeAccent,
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
    );
  }

  // ==========================================
  // DRILL DOWN DIALOG (RESPONSIVE)
  // ==========================================
  void _showMonthlyDetails(BuildContext context, dynamic month) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isMobile ? double.infinity : 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: darkSlate,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Breakdown: ${month.monthKey}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white54),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Daily List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  itemCount: month.items.length,
                  separatorBuilder:
                      (context, index) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final item = month.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: activeAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: activeAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'dd MMM yyyy (EEEE)',
                              ).format(DateTime.parse(item.date)),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: darkSlate,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            "৳ ${item.total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: darkSlate,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Summary Footer
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "MONTH TOTAL:",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                    Text(
                      "৳ ${month.total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: activeAccent,
                      ),
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.boxOpen, size: 50, color: Colors.black12),
          SizedBox(height: 16),
          Text(
            "No expense history found.",
            style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}