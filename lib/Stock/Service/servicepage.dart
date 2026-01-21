// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../controller.dart';

class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  // We use ProductController because it holds the 'serviceLogs' and API logic
  final ProductController controller = Get.find<ProductController>();

  @override
  void initState() {
    super.initState();
    // Fetch fresh logs when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchServiceLogs();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  /// ==================================================
  /// PDF GENERATION LOGIC
  /// ==================================================
  Future<void> _generateAndDownloadPdf(String reportType) async {
    final pdf = pw.Document();

    // Filter Data based on Type
    final isDamage = reportType == 'damage';
    final title = isDamage ? "Damage Report" : "Service Center Report";
    final dataList =
        controller.serviceLogs.where((e) => e['type'] == reportType).toList();

    if (dataList.isEmpty) {
      Get.snackbar("No Data", "There is no data to generate a report for.");
      return;
    }

    // Calculate Totals for Footer
    int totalQty = 0;
    double totalValue = 0.0;

    for (var item in dataList) {
      int q = int.tryParse(item['qty'].toString()) ?? 0;
      double c = double.tryParse(item['return_cost'].toString()) ?? 0.0;
      totalQty += q;
      if (isDamage) {
        totalValue += (q * c);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.TableHelper.fromTextArray(
              headers:
                  isDamage
                      ? ['Model', 'Date', 'Qty', 'Unit Cost', 'Total Loss']
                      : ['Model', 'Date', 'Qty', 'Status'],
              data:
                  dataList.map((item) {
                    final qty = int.tryParse(item['qty'].toString()) ?? 0;
                    final cost =
                        double.tryParse(item['return_cost'].toString()) ?? 0.0;
                    final date = _formatDate(item['created_at']);

                    if (isDamage) {
                      final loss = qty * cost;
                      return [
                        item['model'] ?? 'Unknown',
                        date,
                        qty.toString(),
                        cost.toStringAsFixed(2),
                        loss.toStringAsFixed(2),
                      ];
                    } else {
                      return [
                        item['model'] ?? 'Unknown',
                        date,
                        qty.toString(),
                        item['status'] == 'active' ? 'Pending' : 'Returned',
                      ];
                    }
                  }).toList(),
              border: null,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
            ),

            pw.SizedBox(height: 20),
            pw.Divider(),

            // Footer Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Total Items: $totalQty",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (isDamage)
                      pw.Text(
                        "Total Loss Value: ${totalValue.toStringAsFixed(2)} BDT",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${title}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ==================================================
  // NEW: PARTIAL RETURN DIALOG (The Fix)
  // ==================================================
  void _showReturnDialog(
    BuildContext context,
    int id,
    String modelName,
    int maxQty,
  ) {
    final TextEditingController qtyController = TextEditingController();

    // Default to full quantity for convenience
    qtyController.text = maxQty.toString();

    Get.defaultDialog(
      title: "Return to Stock",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      content: Column(
        children: [
          Text("Return $modelName from Service?"),
          const SizedBox(height: 10),
          Text(
            "Max available: $maxQty",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: "Enter Quantity",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
          ),
        ],
      ),
      textConfirm: "Confirm",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.green,
      onConfirm: () {
        final int enteredQty = int.tryParse(qtyController.text) ?? 0;

        // VALIDATION LOGIC
        if (enteredQty <= 0) {
          Get.snackbar(
            "Error",
            "Quantity must be at least 1",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        if (enteredQty > maxQty) {
          Get.snackbar(
            "Error",
            "Cannot return more than $maxQty",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        Get.back(); // Close Dialog

        // Pass both ID and Quantity to the controller
        controller.returnFromService(id, enteredQty);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Service Center & Damage Log",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // PDF DOWNLOAD BUTTON
          PopupMenuButton<String>(
            icon: const Icon(Icons.print, color: Colors.blue),
            tooltip: "Download Report",
            onSelected: (value) => _generateAndDownloadPdf(value),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'service',
                    child: Row(
                      children: [
                        Icon(Icons.build, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Print Service Report"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'damage',
                    child: Row(
                      children: [
                        Icon(Icons.broken_image, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Print Damage Report"),
                      ],
                    ),
                  ),
                ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => controller.fetchServiceLogs(),
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Logs",
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.build_circle_outlined),
                    text: "Active Service",
                  ),
                  Tab(
                    icon: Icon(Icons.broken_image_outlined),
                    text: "Damage History",
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_buildServiceList(), _buildDamageList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // TAB 1: SERVICE LIST
  // ==================================================
  Widget _buildServiceList() {
    return Obx(() {
      if (controller.isActionLoading.value && controller.serviceLogs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Filter for 'service' type
      final services =
          controller.serviceLogs.where((e) => e['type'] == 'service').toList();

      if (services.isEmpty) {
        return _buildEmptyState(
          Icons.check_circle_outline,
          "All Clear",
          "No products currently in service.",
        );
      }

      // Calculate Summary
      final totalQty = services.fold<int>(0, (sum, item) {
        return item['status'] == 'active'
            ? sum + (int.tryParse(item['qty'].toString()) ?? 0)
            : sum;
      });

      return Column(
        children: [
          _buildSummaryHeader("Items currently pending repair", totalQty),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final item = services[index];
                final bool isActive = item['status'] == 'active';
                final int id = item['id'];
                final int qty = int.tryParse(item['qty'].toString()) ?? 0;
                final double cost =
                    double.tryParse(item['return_cost'].toString()) ?? 0.0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          isActive
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      isActive
                                          ? Colors.orange.shade100
                                          : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.build,
                                    color:
                                        isActive
                                            ? Colors.orange[800]
                                            : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['model'] ?? 'Unknown Model',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(item['created_at']),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isActive
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isActive
                                          ? Colors.orange.shade200
                                          : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                isActive ? "Pending" : "Returned",
                                style: TextStyle(
                                  color:
                                      isActive
                                          ? Colors.orange[800]
                                          : Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Quantity: $qty",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Unit Value: ${cost.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (isActive)
                              ElevatedButton.icon(
                                onPressed: () {
                                  // CHANGED: Open the partial return dialog
                                  _showReturnDialog(
                                    context,
                                    id,
                                    item['model'],
                                    qty,
                                  );
                                },
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text("Return Stock"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  // ==================================================
  // TAB 2: DAMAGE LIST
  // ==================================================
  Widget _buildDamageList() {
    return Obx(() {
      if (controller.isActionLoading.value && controller.serviceLogs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Filter for 'damage' type
      final damages =
          controller.serviceLogs.where((e) => e['type'] == 'damage').toList();

      if (damages.isEmpty) {
        return _buildEmptyState(
          Icons.sentiment_satisfied_alt,
          "No Damage",
          "Great! No damaged items recorded.",
        );
      }

      // Calculate Total Loss
      final totalLoss = damages.fold<double>(0.0, (sum, item) {
        int q = int.tryParse(item['qty'].toString()) ?? 0;
        double c = double.tryParse(item['return_cost'].toString()) ?? 0.0;
        return sum + (q * c);
      });

      return Column(
        children: [
          _buildSummaryHeader(
            "Total Loss Value: ${totalLoss.toStringAsFixed(2)} BDT",
            null,
            isError: true,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: damages.length,
              itemBuilder: (context, index) {
                final item = damages[index];
                final int qty = int.tryParse(item['qty'].toString()) ?? 0;
                final double cost =
                    double.tryParse(item['return_cost'].toString()) ?? 0.0;
                final double totalItemLoss = qty * cost;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    tileColor: Colors.red.shade50.withOpacity(0.3),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Icon(Icons.delete_forever, color: Colors.red[800]),
                    ),
                    title: Text(
                      item['model'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(item['created_at'])),
                          const SizedBox(height: 2),
                          Text(
                            "Loss: $qty x $cost = ${totalItemLoss.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "-$qty",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  // ==================================================
  // HELPER WIDGETS
  // ==================================================
  Widget _buildSummaryHeader(String title, int? count, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: isError ? Colors.red[50] : Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.warning_amber : Icons.info_outline,
            size: 18,
            color: isError ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            count != null ? "$title: $count" : title,
            style: TextStyle(
              color: isError ? Colors.red[900] : Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class PdfService {
  static Future<void> generateShortlistPdf(List<Product> products) async {
    try {
      final doc = pw.Document();

      // 1. LOAD A UNICODE FONT (Fixes "Helvetica has no Unicode support")
      // We use NotoSans because it supports many symbols including Taka sign.
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      doc.addPage(
        pw.MultiPage(
          // 2. INCREASE PAGE LIMIT (Fixes "TooManyPagesException")
          maxPages: 200,

          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),

          // Apply the font to the whole page theme
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),

          header: (context) => _buildHeader(),
          footer: (context) => _buildFooter(context),

          build:
              (context) => [
                _buildSummary(products),
                pw.SizedBox(height: 15),
                _buildProductTable(products),
              ],
        ),
      );

      final String filename =
          'Reorder_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      await Printing.sharePdf(bytes: await doc.save(), filename: filename);
    } catch (e) {
      print("PDF Generation Error: $e");
      rethrow;
    }
  }

  // --- HEADER ---
  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'INVENTORY REORDER REPORT',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Text(
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // --- FOOTER ---
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
      ),
    );
  }

  // --- SUMMARY BOX ---
  static pw.Widget _buildSummary(List<Product> products) {
    int critical = 0;
    for (var p in products) {
      if (p.stockQty == 0) critical++;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text("Total Items", style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                "${products.length}",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                "Critical (0 Stock)",
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                "$critical",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TABLE ---
  static pw.Widget _buildProductTable(List<Product> products) {
    // Preparing data as simple strings to be lightweight
    final data =
        products.map((p) {
          final shortage = p.alertQty - p.stockQty;
          return [
            p.model,
            // Sanitize name: remove newlines/tabs that might break PDF layout
            (p.name.length > 30 ? '${p.name.substring(0, 30)}...' : p.name)
                .replaceAll('\n', ' '),
            p.stockQty.toString(),
            p.alertQty.toString(),
            '+$shortage',
            p.stockQty == 0 ? 'CRITICAL' : 'LOW',
          ];
        }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Model', 'Name', 'Stock', 'Alert', 'Shortage', 'Status'],
      data: data,
      // Font sizes adjusted for A4 width
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 18,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }
}
