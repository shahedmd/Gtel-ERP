// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'controller.dart';
import 'pdf_service.dart';

class ProfitLossPage extends StatelessWidget {
  final controller = Get.put(ProfitLossController());

  // Professional Colors
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color activeAccent = Color(0xFF2563EB);
  static const Color bgGrey = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF10B981);

  ProfitLossPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgGrey,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: activeAccent),
                  );
                }
                return TabBarView(
                  children: [
                    _buildEntityList(controller.customerList),
                    _buildEntityList(controller.debtorList),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: darkSlate,
      elevation: 0,
      title: const Text(
        "PROFIT & LOSS REPORT",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => controller.fetchMonthlyData(),
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: "Refresh Data",
        ),
        Obx(
          () => Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => controller.changeMonth(-1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat(
                    'MMMM yyyy',
                  ).format(controller.selectedDate.value).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => controller.changeMonth(1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ],
      bottom: const TabBar(
        indicatorColor: activeAccent,
        indicatorWeight: 4,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [Tab(text: "RETAIL CUSTOMERS"), Tab(text: "DEBTOR / AGENTS")],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (val) => controller.search(val),
        decoration: InputDecoration(
          hintText: "Search by Phone or Name...",
          prefixIcon: const Icon(Icons.search, color: textMuted),
          filled: true,
          fillColor: bgGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildEntityList(List<GroupedEntity> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text("No records found", style: TextStyle(color: textMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (c, i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entity = list[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: activeAccent.withOpacity(0.1),
              child: Text(
                entity.name[0].toUpperCase(),
                style: const TextStyle(
                  color: activeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              entity.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
            subtitle: Text(
              entity.phone == "N/A" || entity.phone == entity.id
                  ? "ID: ${entity.id}"
                  : entity.phone,
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "TOTAL SALE",
                  style: TextStyle(
                    fontSize: 10,
                    color: textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "৳${entity.totalSale.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: darkSlate,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                
              ],
            ),
            onTap:
                () => Get.to(
                  () => EntityHistoryPage(
                    entity: entity,
                    month: controller.selectedDate.value,
                  ),
                ),
          ),
        );
      },
    );
  }
}

// --- HISTORY PAGE (Detailed View) ---
class EntityHistoryPage extends StatelessWidget {
  final GroupedEntity entity;
  final DateTime month;

  const EntityHistoryPage({
    super.key,
    required this.entity,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfitLossPage.bgGrey,
      appBar: AppBar(
        backgroundColor: ProfitLossPage.darkSlate,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entity.name, style: const TextStyle(fontSize: 16)),
            Text(
              "Detailed Report",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: "Print PDF",
            onPressed:
                () =>
                    ProfitLossPdfService.generateDetailedReport(entity, month),
          ),
        ],
      ),
      body: Column(
        children: [
          // SUMMARY HEADER
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _miniStat(
                    "Total Sales",
                    entity.totalSale,
                    Colors.black87,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: _miniStat(
                    "Net Profit",
                    entity.totalProfit,
                    ProfitLossPage.successGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),

          // INVOICE LIST
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entity.invoices.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final inv = entity.invoices[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      inv.invoiceId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ProfitLossPage.darkSlate,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(inv.date),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "SALE: ৳${inv.sale.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: ProfitLossPage.darkSlate,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "PROFIT: ৳${inv.profit.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ProfitLossPage.successGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double val, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: ProfitLossPage.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "৳${val.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
