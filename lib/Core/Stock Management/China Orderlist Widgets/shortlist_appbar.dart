// lib/Core/Stock Management/widgets/shortlist_appbar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockproductmodel.dart';

import '../../Core Utils/activity_logger.dart';
import '../../Permission/permission_button.dart';
import '../stock_shorlist_and_china_order.dart';

class ShortlistAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isMobile;
  final OrderCartController cartController;
  final ProductController controller;
  final VoidCallback onShowCart;

  const ShortlistAppBar({
    super.key,
    required this.isMobile,
    required this.cartController,
    required this.controller,
    required this.onShowCart,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFF0F172A),
            size: isMobile ? 22 : 26,
          ),
          const SizedBox(width: 10),
          Text(
            'Stock Alerts',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              fontSize: isMobile ? 18 : 22,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      actions: isMobile ? _mobileActions(context) : _desktopActions(context),
    );
  }

  List<Widget> _mobileActions(BuildContext context) {
    return [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
        onSelected: (v) {
          if (v == 'export') _handleExport();
          if (v == 'cart') onShowCart();
        },
        itemBuilder:
            (_) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.blue),
                  title: Text('Export PDF', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'cart',
                child: Obx(
                  () => ListTile(
                    leading: const Icon(Icons.shopping_cart, color: Colors.red),
                    title: Text(
                      'Cart (${cartController.cartItems.length})',
                      style: const TextStyle(fontSize: 13),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
      ),
    ];
  }

  List<Widget> _desktopActions(BuildContext context) {
    return [
      // Export — canView permission লাগবে
      PermissionButton(
        route: Routes.stock,
        type: PermissionType.canView,
        child: ElevatedButton.icon(
          onPressed: _handleExport,
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Export List'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
      const SizedBox(width: 12),

      // Cart — canCreate permission লাগবে
      PermissionButton(
        route: Routes.stock,
        type: PermissionType.canCreate,
        child: Obx(
          () => ElevatedButton.icon(
            onPressed: onShowCart,
            icon: const Icon(Icons.shopping_cart, size: 18),
            label: Text('Cart (${cartController.cartItems.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ),
      const SizedBox(width: 20),
    ];
  }

  Future<void> _handleExport() async {
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final allData = await controller.fetchAllShortListForExport();
      if (allData.isNotEmpty) {
        await PdfService.generateShortlistPdf(allData);
        await ActivityLogger.log(
          action: 'EXPORT_SHORTLIST',
          module: 'Stock',
          details: 'Exported ${allData.length} low stock items to PDF',
        );
        Get.back();
        Get.snackbar(
          'Success',
          'PDF Generated',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.back();
        Get.snackbar(
          'Info',
          'No data to export',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        '$e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PDF Service — shortlist export
// ─────────────────────────────────────────────────────────────
class PdfService {
  static Future<void> generateShortlistPdf(List<Product> products) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              pw.Text(
                'LOW STOCK REPORT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.red800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                headers: [
                  'Model',
                  'Product Name',
                  'Current Stock',
                  'Alert Qty',
                  'Sea Price',
                  'Air Price',
                ],
                data:
                    products
                        .map(
                          (p) => [
                            p.model,
                            p.name,
                            p.stockQty.toString(),
                            p.alertQty.toString(),
                            '৳${p.sea.toStringAsFixed(0)}',
                            '৳${p.air.toStringAsFixed(0)}',
                          ],
                        )
                        .toList(),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Low_Stock_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf',
    );
  }
}