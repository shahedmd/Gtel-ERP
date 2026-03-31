// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
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
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          // 1. ADDED LOADING INDICATOR FOR PDF GENERATION
          Obx(() {
            if (controller.isPdfGenerating.value) {
              return const Padding(
                padding: EdgeInsets.only(right: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }
            return IconButton(
              onPressed: () => controller.downloadPdf(),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: "Export PDF",
            );
          }),
          const SizedBox(width: 5),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopSection(context)),
          SliverToBoxAdapter(child: _buildTableHeader()),
          Obx(() {
            if (controller.isLoading.value) {
              return const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: brandBlue),
                ),
              );
            }
            if (controller.paginatedList.isEmpty) {
              return SliverFillRemaining(child: _buildEmptyState());
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = controller.paginatedList[index];
                final rank =
                    ((controller.currentPage.value - 1) *
                        controller.itemsPerPage) +
                    index +
                    1;
                return Column(
                  children: [
                    _buildTableRow(item, rank, index % 2 == 0),
                    const Divider(height: 1, color: borderGrey),
                  ],
                );
              }, childCount: controller.paginatedList.length),
            );
          }),
          SliverToBoxAdapter(child: _buildPaginationControls()),
        ],
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (val) => controller.searchQuery.value = val,
                    decoration: InputDecoration(
                      hintText: "Search Name or Phone...",
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      filled: true,
                      fillColor: bgLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: borderGrey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: borderGrey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: bgLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderGrey),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: Obx(
                      () => DropdownButton<String>(
                        isExpanded: true,
                        value: controller.selectedGroup.value,
                        icon: const Icon(
                          Icons.filter_list,
                          size: 16,
                          color: brandBlue,
                        ),
                        items:
                            controller.groupOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => controller.selectedGroup.value = v!,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderGrey),
                ),
                child: DropdownButtonHideUnderline(
                  child: Obx(
                    () => DropdownButton<String>(
                      value: controller.selectedDateFilter.value,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      items:
                          controller.dateFilterOptions
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (v) => controller.selectedDateFilter.value = v!,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() {
                  if (controller.selectedDateFilter.value == 'Custom') {
                    return Row(
                      children: [
                        _buildDatePicker(
                          context,
                          controller.customStartDate.value,
                          (date) => controller.customStartDate.value = date,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            "-",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildDatePicker(
                          context,
                          controller.customEndDate.value,
                          (date) => controller.customEndDate.value = date,
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                }),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => controller.generateReport(),
                  icon: const Icon(Icons.analytics, size: 16),
                  label: const Text("Generate", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(
            () => Row(
              children: [
                _summaryCard(
                  "Total Customers",
                  controller.totalItems.value.toString(),
                  Icons.groups,
                  Colors.purple,
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  "Total Sales",
                  "Tk ${controller.formatCurrency(controller.periodTotalSales.value)}",
                  Icons.bar_chart,
                  darkBlue,
                ),
                const SizedBox(width: 10),
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

  Widget _buildDatePicker(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onPicked,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: borderGrey),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            DateFormat('dd MMM yy').format(initialDate),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: darkBlue),
      child: Row(
        children: [
          _headerText("Rank", flex: 1, align: TextAlign.center),
          _headerText("Customer Info", flex: 4),
          _headerText("Type", flex: 2, align: TextAlign.center),
          _headerText("Orders", flex: 1, align: TextAlign.center),
          _headerText("Total Sales", flex: 2, align: TextAlign.right),
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
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTableRow(CustomerAnalyticsModel item, int rank, bool isEven) {
    return InkWell(
      onTap: () {
        controller.loadCustomerDetails(item);
        Get.to(() => CustomerDetailsPage());
      },
      hoverColor: Colors.blue.withOpacity(0.1),
      child: Container(
        color: isEven ? Colors.white : bgLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  fontSize: 12,
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
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        item.phone.isEmpty ? "No Phone" : item.phone,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 10,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        item.customerType == 'AGENT'
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          item.customerType == 'AGENT'
                              ? Colors.orange
                              : Colors.blue,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    item.customerType,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color:
                          item.customerType == 'AGENT'
                              ? Colors.orange[800]
                              : Colors.blue[800],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                item.orderCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                controller.formatCurrency(item.totalSales),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textDark,
                  fontSize: 11,
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
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => Text(
              "Showing ${controller.paginatedList.length} of ${controller.totalItems.value}",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => controller.prevPage(),
                icon: const Icon(Icons.chevron_left, size: 20),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              Obx(
                () => Text(
                  "Page ${controller.currentPage.value} of ${controller.totalPages}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => controller.nextPage(),
                icon: const Icon(Icons.chevron_right, size: 20),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
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
          Icon(Icons.analytics_outlined, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "No records found",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// CUSTOMER DETAILS & INVOICE HISTORY PAGE
// =========================================================================
class CustomerDetailsPage extends StatelessWidget {
  CustomerDetailsPage({super.key});

  final controller = Get.find<CustomerAnalyticsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerAnalyticsPage.bgLight,
      appBar: AppBar(
        title: const Text(
          "Customer History",
          style: TextStyle(
            color: CustomerAnalyticsPage.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: CustomerAnalyticsPage.textDark),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!controller.isDetailsLoadingMore.value &&
              controller.hasMoreInvoices.value &&
              scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 50) {
            controller.loadMoreInvoices();
          }
          return false;
        },
        child: Obx(() {
          final profile = controller.selectedCustomerProfile.value;
          if (profile == null) {
            return const Center(child: Text("Error: No Customer Selected"));
          }

          return CustomScrollView(
            slivers: [
              // PROFILE CARD
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CustomerAnalyticsPage.darkBlue,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: CustomerAnalyticsPage.brandBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              profile.customerType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _infoRow(Icons.phone, profile.phone),
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.store,
                        profile.shopName.isEmpty
                            ? "No Shop Name"
                            : profile.shopName,
                      ),
                      const SizedBox(height: 4),
                      _infoRow(Icons.location_on, profile.address),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _profileStat(
                            "Total Orders",
                            profile.orderCount.toString(),
                          ),
                          _profileStat(
                            "Total Sales",
                            "৳${controller.formatCurrency(profile.totalSales)}",
                          ),
                          _profileStat(
                            "Total Profit",
                            "৳${controller.formatCurrency(profile.totalProfit)}",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // TRANSACTION HISTORY TITLE
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(top: 8),
                  color: CustomerAnalyticsPage.darkBlue,
                  child: const Text(
                    "Recent Invoice History",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              // INVOICE LIST
              if (controller.isDetailsLoading.value)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (controller.selectedCustomerInvoices.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No transactions found.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    var invoice = controller.selectedCustomerInvoices[index];
                    DateTime date =
                        (invoice['timestamp'] as Timestamp).toDate();
                    String documentId = invoice['id']; // Used for reprinting

                    bool isFullyPaid = invoice['isFullyPaid'] ?? false;
                    double grandTotal =
                        double.tryParse(invoice['grandTotal'].toString()) ??
                        0.0;
                    double paid =
                        double.tryParse(invoice['paid'].toString()) ?? 0.0;
                    double profit =
                        double.tryParse(invoice['profit'].toString()) ?? 0.0;
                    double due = grandTotal - paid;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(
                          color: CustomerAnalyticsPage.borderGrey,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Invoice: ${invoice['invoiceId']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(date),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Amount: ৳${controller.formatCurrency(grandTotal)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Profit: ৳${controller.formatCurrency(profit)}",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),

                                // 3. BADGE & REPRINT BUTTON ROW
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isFullyPaid
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              isFullyPaid
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            isFullyPaid ? "PAID" : "DUE",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color:
                                                  isFullyPaid
                                                      ? Colors.green
                                                      : Colors.red,
                                            ),
                                          ),
                                          if (!isFullyPaid && due > 0)
                                            Text(
                                              "৳${controller.formatCurrency(due)}",
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // REPRINT BUTTON
                                    Obx(() {
                                      if (controller
                                              .reprintingInvoiceId
                                              .value ==
                                          documentId) {
                                        return const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: Padding(
                                            padding: EdgeInsets.all(6.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      return IconButton(
                                        icon: const Icon(
                                          Icons.print,
                                          color: Colors.blue,
                                        ),
                                        tooltip: "Reprint Invoice",
                                        onPressed:
                                            () => controller.reprintInvoice(
                                              documentId,
                                            ),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: controller.selectedCustomerInvoices.length),
                ),

              // LOAD MORE INDICATOR
              if (controller.isDetailsLoadingMore.value)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              // SPACING AT BOTTOM
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        }),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800], fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _profileStat(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: CustomerAnalyticsPage.textDark,
          ),
        ),
      ],
    );
  }
}