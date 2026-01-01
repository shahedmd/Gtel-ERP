// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'controller.dart';

class ProfitLossReportPage extends StatelessWidget {
  const ProfitLossReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfitLossController());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
      appBar: AppBar(
        title: const Text(
          "FINANCIAL ANALYTICS",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey[900],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => controller.fetchAnalytics(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        return Column(
          children: [
            _buildProfessionalHeader(controller),
            const SizedBox(height: 10),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        labelColor: Colors.blue[700],
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue[700],
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: "RETAIL SALES"),
                          Tab(text: "DEBTOR SALES"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildModernOrderList(
                            controller.customerOrders,
                            "Retail",
                          ),
                          _buildModernOrderList(
                            controller.debtorOrders,
                            "Debtor",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProfessionalHeader(ProfitLossController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _dashboardCard(
            "REVENUE",
            controller.totalRevenue.value,
            const Color(0xFF2563EB),
            Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(width: 15),
          _dashboardCard(
            "TOTAL COST",
            controller.totalCost.value,
            const Color(0xFFEA580C),
            Icons.shopping_cart_checkout,
          ),
          const SizedBox(width: 15),
          _dashboardCard(
            "NET PROFIT",
            controller.totalProfit.value,
            const Color(0xFF16A34A),
            Icons.trending_up_rounded,
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 18,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                "৳ ${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernOrderList(List<Map<String, dynamic>> orders, String type) {
    if (orders.isEmpty) {
      return const Center(child: Text("No records found for this category"));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final profit = (order['profit'] ?? 0.0).toDouble();
        final timestamp = order['timestamp'] as Timestamp?;
        final date = timestamp != null ? timestamp.toDate() : DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: profit >= 0 ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                profit >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: profit >= 0 ? Colors.green[700] : Colors.red[700],
                size: 20,
              ),
            ),
            title: Text(
              "Inv: ${order['invoiceId']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              DateFormat('dd MMM yyyy | hh:mm a').format(date),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "৳ ${profit.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: profit >= 0 ? Colors.green[700] : Colors.red[700],
                    fontSize: 16,
                  ),
                ),
                const Text(
                  "ORDER PROFIT",
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
            children: [_buildOrderDetail(order)],
          ),
        );
      },
    );
  }

  Widget _buildOrderDetail(Map<String, dynamic> order) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(
                "TOTAL SALE",
                (order['totalAmount'] ?? order['saleAmount'] ?? 0.0).toDouble(),
                Colors.blue,
              ),
              _summaryItem(
                "TOTAL COST",
                (order['costAmount'] ?? 0.0).toDouble(),
                Colors.orange,
              ),
              _summaryItem(
                "DISCOUNT",
                (order['discount'] ?? 0.0).toDouble(),
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "ITEMIZED BREAKDOWN",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const Divider(),
          ...(order['items'] as List? ?? []).map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${item['qty']}x ${item['name']}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    "৳${item['salePrice'].toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    "(Cost: ৳${item['buyPrice'].toStringAsFixed(2)})",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _generateProfitPdf(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[900],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text("GENERATE PROFIT REPORT"),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "৳${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PDF GENERATOR (NO HTML PACKAGE)
  // ==========================================
  Future<void> _generateProfitPdf(Map<String, dynamic> order) async {
    final pdf = pw.Document();
    final timestamp = order['timestamp'] as Timestamp?;
    final dateStr = DateFormat(
      'dd-MM-yyyy hh:mm a',
    ).format(timestamp?.toDate() ?? DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "G-TEL ERP: PROFIT ANALYSIS",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Invoice ID: ${order['invoiceId']}"),
                    pw.Text("Date: $dateStr"),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue900,
                  ),
                  data: [
                    [
                      'Qty',
                      'Item Name',
                      'Cost Price',
                      'Sale Price',
                      'Item Profit',
                    ],
                    ...(order['items'] as List).map((i) {
                      double itemProfit =
                          (i['salePrice'] - i['buyPrice']) * i['qty'];
                      return [
                        i['qty'].toString(),
                        i['name'],
                        i['buyPrice'].toStringAsFixed(2),
                        i['salePrice'].toStringAsFixed(2),
                        itemProfit.toStringAsFixed(2),
                      ];
                    }),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  child: pw.Column(
                    children: [
                      _pdfRow(
                        "Total Sales Revenue",
                        (order['totalAmount'] ?? order['saleAmount'] ?? 0.0)
                            .toDouble(),
                      ),
                      _pdfRow(
                        "Total Inventory Cost",
                        (order['costAmount'] ?? 0.0).toDouble(),
                      ),
                      _pdfRow(
                        "Discount Given",
                        (order['discount'] ?? 0.0).toDouble(),
                      ),
                      pw.Divider(),
                      _pdfRow(
                        "NET INVOICE PROFIT",
                        (order['profit'] ?? 0.0).toDouble(),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    "CONFIDENTIAL FINANCIAL REPORT - G-TEL POS",
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _pdfRow(String label, double value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            "Tk ${value.toStringAsFixed(2)}",
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
