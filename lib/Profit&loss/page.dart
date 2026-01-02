import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'controller.dart';
import 'pdf_service.dart';

class ProfitLossPage extends StatelessWidget {
  final controller = Get.put(ProfitLossController());

  // Colors based on your requirements
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

   ProfitLossPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgGrey,
        appBar: AppBar(
          backgroundColor: darkSlate,
          elevation: 0,
          title: const Text(
            "Profit & Loss Analytics",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          actions: [
            Obx(
              () => Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () => controller.changeMonth(-1),
                  ),
                  Text(
                    DateFormat(
                      'MMM yyyy',
                    ).format(controller.selectedDate.value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () => controller.changeMonth(1),
                  ),
                ],
              ),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: activeAccent,
            indicatorWeight: 3,
            labelColor: activeAccent,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: "RETAIL CUSTOMERS"), Tab(text: "DEBTOR AGENTS")],
          ),
        ),
        body: Obx(() {
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
    );
  }

  Widget _buildEntityList(List<GroupedEntity> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          "No records found for this month",
          style: TextStyle(color: textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entity = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              entity.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkSlate,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Monthly Sales: \$${entity.totalSale.toStringAsFixed(2)}",
                style: const TextStyle(color: textMuted),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "NET PROFIT",
                  style: TextStyle(
                    fontSize: 10,
                    color: textMuted,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  "\$${entity.totalProfit.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
        title: Text(entity.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed:
                () =>
                    ProfitLossPdfService.generateDetailedReport(entity, month),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat("Total Sale", entity.totalSale),
                _miniStat("Total Profit", entity.totalProfit),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entity.invoices.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (context, index) {
                final inv = entity.invoices[index];
                return ListTile(
                  title: Text(
                    inv.invoiceId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(inv.date),
                  ),
                  trailing: Text(
                    "+\$${inv.profit.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
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

  Widget _miniStat(String label, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: ProfitLossPage.textMuted, fontSize: 12),
        ),
        Text(
          "\$${val.toStringAsFixed(2)}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ProfitLossPage.darkSlate,
          ),
        ),
      ],
    );
  }
}
