import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and triggers the system print / share sheet for service reports.
///
/// Completely decoupled from the widget tree — no [BuildContext] needed.
abstract final class ServicePdfGenerator {
  static final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final _titleFmt = DateFormat('MMM dd, yyyy');
  static final _fileFmt = DateFormat('yyyyMMdd_HHmm');

  /// [reportType] must be either `'service'` or `'damage'`.
  static Future<void> generate({
    required String reportType,
    required List<Map<String, dynamic>> logs,
  }) async {
    final isDamage = reportType == 'damage';
    final filtered = logs.where((e) => e['type'] == reportType).toList();

    if (filtered.isEmpty) {
      Get.snackbar(
        'No Data',
        'There is no data to generate a report for.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final title = isDamage ? 'DAMAGE HISTORY REPORT' : 'ACTIVE SERVICE LOG';
    final stats = _computeStats(filtered, isDamage: isDamage);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (ctx) => [
              _buildTitle(title),
              pw.SizedBox(height: 20),
              _buildTable(filtered, isDamage: isDamage),
              pw.SizedBox(height: 15),
              _buildTotals(stats, isDamage: isDamage),
              pw.Spacer(),
              _buildSignatures(),
            ],
      ),
    );

    final filename =
        '${title.replaceAll(' ', '_')}_${_fileFmt.format(DateTime.now())}.pdf';

    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: filename);
  }

  // ── Private builders ──────────────────────────────────────────────────────

  static pw.Widget _buildTitle(String title) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.Text(
        'Date: ${_titleFmt.format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    ],
  );

  static pw.Widget _buildTable(
    List<Map<String, dynamic>> data, {
    required bool isDamage,
  }) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      cellAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      headers:
          isDamage
              ? ['No.', 'Date', 'Model', 'Qty', 'Unit Cost', 'Total Loss']
              : ['No.', 'Date', 'Model', 'Qty', 'Status'],
      data: List.generate(data.length, (i) {
        final item = data[i];
        final qty = int.tryParse(item['qty'].toString()) ?? 0;
        final cost = double.tryParse(item['return_cost'].toString()) ?? 0.0;
        final date =
            item['created_at'] != null
                ? _dateFmt.format(DateTime.parse(item['created_at']).toLocal())
                : 'N/A';

        if (isDamage) {
          return [
            '${i + 1}',
            date,
            item['model'] ?? '-',
            '$qty',
            'Tk ${cost.toStringAsFixed(2)}',
            'Tk ${(qty * cost).toStringAsFixed(2)}',
          ];
        } else {
          return [
            '${i + 1}',
            date,
            item['model'] ?? '-',
            '$qty',
            item['status'] == 'active' ? 'Pending' : 'Returned',
          ];
        }
      }),
    );
  }

  static pw.Widget _buildTotals(_ReportStats stats, {required bool isDamage}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Total Items: ${stats.totalQty}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (isDamage) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Total Loss Value: Tk ${stats.totalValue.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatures() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      _signatureLine('Prepared By'),
      _signatureLine('Authorized Signature'),
    ],
  );

  static pw.Widget _signatureLine(String label) => pw.Column(
    children: [
      pw.Container(width: 120, height: 1, color: PdfColors.black),
      pw.SizedBox(height: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    ],
  );

  static _ReportStats _computeStats(
    List<Map<String, dynamic>> data, {
    required bool isDamage,
  }) {
    int totalQty = 0;
    double totalValue = 0.0;
    for (final item in data) {
      final qty = int.tryParse(item['qty'].toString()) ?? 0;
      final cost = double.tryParse(item['return_cost'].toString()) ?? 0.0;
      totalQty += qty;
      if (isDamage) totalValue += qty * cost;
    }
    return _ReportStats(totalQty: totalQty, totalValue: totalValue);
  }
}

class _ReportStats {
  const _ReportStats({required this.totalQty, required this.totalValue});
  final int totalQty;
  final double totalValue;
}