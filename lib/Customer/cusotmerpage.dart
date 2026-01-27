// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Customer/customercontroller.dart';
import 'package:intl/intl.dart';

class CustomerAnalyticsPage extends StatelessWidget {
  CustomerAnalyticsPage({super.key});

  final controller = Get.put(CustomerAnalyticsController());

  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color profitGreen = Color(0xFF10B981);
  static const Color bgGrey = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text(
          "Customer Analytics",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: darkSlate,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => controller.downloadPdf(),
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: "Download PDF",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // 1. FILTER SECTION
          _buildFilterSection(context),

          // 2. SUMMARY CARDS
          Obx(() => _buildSummaryCards()),

          // 3. TABLE HEADERS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: darkSlate,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    "Rank",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    "Customer Name",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Orders",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "Total Sales",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Profit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. DATA LIST
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: activeAccent),
                );
              }
              if (controller.aggregatedList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        "No Data Generated",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => controller.generateReport(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Tap to Generate"),
                        style: TextButton.styleFrom(
                          foregroundColor: activeAccent,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.aggregatedList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = controller.aggregatedList[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Rank Badge
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: CircleAvatar(
                              backgroundColor:
                                  index < 3
                                      ? Colors.amber[100]
                                      : Colors.grey[100],
                              radius: 12,
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color:
                                      index < 3
                                          ? Colors.amber[800]
                                          : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Customer Name
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: darkSlate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.phone.isNotEmpty)
                                Text(
                                  item.phone,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Orders
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.orderCount.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: activeAccent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Sales
                        Expanded(
                          flex: 3,
                          child: Text(
                            NumberFormat.compact().format(
                              item.totalSales,
                            ), // Use Compact for cleaner look (e.g. 1.2K)
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: darkSlate,
                            ),
                          ),
                        ),
                        // Profit
                        Expanded(
                          flex: 2,
                          child: Text(
                            NumberFormat.compact().format(item.totalProfit),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: profitGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Report Type Toggle
              Obx(
                () => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ToggleButtons(
                    isSelected: [
                      !controller.isYearlyReport.value,
                      controller.isYearlyReport.value,
                    ],
                    onPressed: (index) {
                      controller.isYearlyReport.value = (index == 1);
                    },
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[600],
                    selectedColor: Colors.white,
                    fillColor: activeAccent,
                    splashColor: Colors.transparent,
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      minWidth: 100,
                    ),
                    renderBorder: false,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    children: const [Text("Monthly"), Text("Yearly")],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Year Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Obx(
                  () => DropdownButton<int>(
                    value: controller.selectedYear.value,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: activeAccent,
                    ),
                    underline: Container(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                      fontSize: 16,
                    ),
                    items:
                        List.generate(5, (index) => DateTime.now().year - index)
                            .map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => controller.selectedYear.value = val!,
                  ),
                ),
              ),

              const SizedBox(width: 15),

              // Month Dropdown (Visible only if Monthly selected)
              Obx(
                () => Visibility(
                  visible: !controller.isYearlyReport.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: controller.selectedMonth.value,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: activeAccent,
                      ),
                      underline: Container(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkSlate,
                        fontSize: 16,
                      ),
                      items:
                          List.generate(12, (index) => index + 1)
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    DateFormat('MMM').format(DateTime(2022, m)),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => controller.selectedMonth.value = val!,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkSlate,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              onPressed: () => controller.generateReport(),
              icon: const Icon(Icons.analytics, size: 20),
              label: const Text(
                "GENERATE REPORT",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _statCard(
            "Total Customers",
            controller.aggregatedList.length.toString(),
            Icons.people,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _statCard(
            "Total Sales",
            NumberFormat.compact().format(controller.periodTotalSales.value),
            Icons.attach_money,
            darkSlate,
          ),
          const SizedBox(width: 12),
          _statCard(
            "Total Profit",
            NumberFormat.compact().format(controller.periodTotalProfit.value),
            Icons.trending_up,
            profitGreen,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color.withOpacity(0.8)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
