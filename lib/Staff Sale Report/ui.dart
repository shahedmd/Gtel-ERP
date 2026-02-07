// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Staff%20Sale%20Report/salecontroller.dart';
import 'package:intl/intl.dart';

class StaffReportScreen extends StatelessWidget {
  const StaffReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StaffReportController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Sales Performance"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          // PDF Download Button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Download Report",
            onPressed: () => controller.generatePdf(),
          ),
          const SizedBox(width: 10),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchReport(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // 1. DATE FILTER SECTION
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blueGrey),
                const SizedBox(width: 10),
                Obx(
                  () => Text(
                    "${DateFormat('dd MMM yyyy').format(controller.startDate.value)}  -  ${DateFormat('dd MMM yyyy').format(controller.endDate.value)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text("Select Date Range"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: controller.startDate.value,
                        end: controller.endDate.value,
                      ),
                    );
                    if (picked != null) {
                      controller.pickDateRange(picked.start, picked.end);
                    }
                  },
                ),
              ],
            ),
          ),

          // 2. SUMMARY CARDS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildSummaryCard(
                  controller,
                  "Total Revenue",
                  (c) => c.grandTotalSales,
                  Colors.blue,
                ),
                const SizedBox(width: 20),
                _buildSummaryCard(
                  controller,
                  "Total Profit",
                  (c) => c.grandTotalProfit,
                  Colors.green,
                ),
              ],
            ),
          ),

          const Divider(),

          // 3. DATA TABLE (ERP STYLE)
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.staffStats.isEmpty) {
                return const Center(
                  child: Text("No sales records found for this period."),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      Colors.blueGrey[50],
                    ),
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Staff Name',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Invoices',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total Sales (Tk)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Net Profit (Tk)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Performance',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows:
                        controller.staffStats.map((staff) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blueGrey[100],
                                      radius: 15,
                                      child: Text(
                                        staff.name.isNotEmpty
                                            ? staff.name[0].toUpperCase()
                                            : "?",
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(staff.name),
                                  ],
                                ),
                              ),
                              DataCell(Text(staff.totalInvoices.toString())),
                              DataCell(
                                Text(
                                  NumberFormat.currency(
                                    symbol: '',
                                    decimalDigits: 2,
                                  ).format(staff.totalSales),
                                ),
                              ),
                              DataCell(
                                Text(
                                  NumberFormat.currency(
                                    symbol: '',
                                    decimalDigits: 2,
                                  ).format(staff.totalProfit),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        staff.margin > 10
                                            ? Colors.green[100]
                                            : Colors.amber[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${staff.margin.toStringAsFixed(1)}% Margin",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          staff.margin > 10
                                              ? Colors.green[900]
                                              : Colors.amber[900],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    StaffReportController controller,
    String title,
    double Function(StaffReportController) valueGetter,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 10),
            Obx(
              () => Text(
                "Tk ${NumberFormat.currency(symbol: '', decimalDigits: 2).format(valueGetter(controller))}",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
