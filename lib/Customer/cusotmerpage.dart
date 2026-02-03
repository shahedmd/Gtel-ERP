// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Customer/customercontroller.dart';
import 'package:gtel_erp/Customer/model.dart';
import 'package:intl/intl.dart';

class CustomerAnalyticsPage extends StatelessWidget {
  CustomerAnalyticsPage({super.key});

  final controller = Get.put(CustomerAnalyticsController());

  // Professional Color Palette
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color bgLight = Color(0xFFF1F5F9);
  static const Color borderGrey = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Customer Performance",
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          IconButton(
            onPressed: () => controller.downloadPdf(),
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
            tooltip: "Export PDF",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // 1. FILTER & SUMMARY
          _buildTopSection(context),

          // 2. DATA TABLE HEADER
          _buildTableHeader(),

          // 3. PAGINATED LIST
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: brandBlue),
                );
              }
              if (controller.paginatedList.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: controller.paginatedList.length,
                separatorBuilder:
                    (c, i) => const Divider(height: 1, color: borderGrey),
                itemBuilder: (context, index) {
                  final item = controller.paginatedList[index];
                  // Calculate absolute rank based on page
                  final rank =
                      ((controller.currentPage.value - 1) *
                          controller.itemsPerPage) +
                      index +
                      1;
                  return _buildTableRow(item, rank, index % 2 == 0);
                },
              );
            }),
          ),

          // 4. PAGINATION CONTROLS
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filters
          Row(
            children: [
              // 1. Report Type Dropdown (Daily, Monthly, Yearly)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderGrey),
                ),
                child: DropdownButtonHideUnderline(
                  child: Obx(
                    () => DropdownButton<String>(
                      value: controller.reportType.value,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      items:
                          ['Daily', 'Monthly', 'Yearly']
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => controller.reportType.value = v!,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Conditional Inputs
              Expanded(
                child: Obx(() {
                  String type = controller.reportType.value;
                  return Row(
                    children: [
                      // If DAILY: Show Date Picker
                      if (type == 'Daily')
                        InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: controller.selectedDate.value,
                              firstDate: DateTime(2022),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    primaryColor: brandBlue,
                                    colorScheme: const ColorScheme.light(
                                      primary: brandBlue,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              controller.selectedDate.value = picked;
                            }
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: borderGrey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(controller.selectedDate.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // If MONTHLY or YEARLY: Show Year
                      if (type != 'Daily')
                        Obx(
                          () => _dropdown(
                            width: 80,
                            value: controller.selectedYear.value,
                            items: List.generate(
                              5,
                              (i) => DateTime.now().year - i,
                            ),
                            onChanged: (v) => controller.selectedYear.value = v,
                          ),
                        ),

                      if (type != 'Daily') const SizedBox(width: 10),

                      // If MONTHLY: Show Month
                      // FIX: Removed Obx() wrapper here because _monthDropdown has its own internal Obx
                      if (type == 'Monthly') _monthDropdown(),
                    ],
                  );
                }),
              ),

              const SizedBox(width: 10),

              ElevatedButton.icon(
                onPressed: () => controller.generateReport(),
                icon: const Icon(Icons.search, size: 18),
                label: const Text("Generate"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Cards
          Obx(
            () => Row(
              children: [
                _summaryCard(
                  "Total Customers",
                  controller.totalItems.value.toString(),
                  Icons.groups,
                  Colors.purple,
                ),
                const SizedBox(width: 15),
                _summaryCard(
                  "Total Sales",
                  "Tk ${controller.formatCurrency(controller.periodTotalSales.value)}",
                  Icons.bar_chart,
                  darkBlue,
                ),
                const SizedBox(width: 15),
                _summaryCard(
                  "Total Profit",
                  "Tk ${controller.formatCurrency(controller.periodTotalProfit.value)}",
                  Icons.pie_chart,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _dropdown({
    required double width,
    required int value,
    required List<int> items,
    required Function(int) onChanged,
  }) {
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items:
              items
                  .map(
                    (i) =>
                        DropdownMenuItem(value: i, child: Text(i.toString())),
                  )
                  .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  Widget _monthDropdown() {
    return Container(
      width: 100,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: Obx(
          () => DropdownButton<int>(
            value: controller.selectedMonth.value,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            items:
                List.generate(12, (i) => i + 1)
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          DateFormat('MMM').format(DateTime(2022, m)),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => controller.selectedMonth.value = v!,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: darkBlue,
        border: Border(bottom: BorderSide(color: borderGrey)),
      ),
      child: Row(
        children: [
          _headerText("Rank", flex: 1, align: TextAlign.center),
          _headerText("Customer Name / Phone", flex: 4),
          _headerText("Orders", flex: 2, align: TextAlign.center),
          _headerText("Total Sales", flex: 3, align: TextAlign.right),
          _headerText("Profit", flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerText(
    String text, {
    required int flex,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTableRow(CustomerAnalyticsModel item, int rank, bool isEven) {
    return Container(
      color: isEven ? Colors.white : bgLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              "#$rank",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textDark,
                    fontSize: 13,
                  ),
                ),
                if (item.phone.isNotEmpty)
                  Text(
                    item.phone,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (item.shopName.isNotEmpty)
                  Text(
                    item.shopName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blueGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.orderCount.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              controller.formatCurrency(item.totalSales),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              controller.formatCurrency(item.totalProfit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderGrey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => Text(
              "Showing ${controller.paginatedList.length} of ${controller.totalItems.value} records",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => controller.prevPage(),
                icon: const Icon(Icons.chevron_left),
                splashRadius: 20,
              ),
              Obx(
                () => Text(
                  "Page ${controller.currentPage.value} of ${controller.totalPages}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => controller.nextPage(),
                icon: const Icon(Icons.chevron_right),
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
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
          Icon(Icons.analytics_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "No records found",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            "Try changing the date filters",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }
}