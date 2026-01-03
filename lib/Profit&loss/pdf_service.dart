// ignore_for_file: deprecated_member_use

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'controller.dart';

class ProfitLossPdfService {
  static Future<void> generateDetailedReport(
    GroupedEntity entity,
    DateTime month,
  ) async {
    final pdf = pw.Document();
    final dateLabel = DateFormat('MMMM yyyy').format(month);
    final font = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Monthly Sales & Profit Report",
                      style: pw.TextStyle(fontSize: 20, font: bold),
                    ),
                    pw.Text(
                      dateLabel,
                      style: pw.TextStyle(font: font, fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Customer Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Customer Name",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            entity.name,
                            style: pw.TextStyle(font: bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            "Phone Number",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            entity.phone,
                            style: pw.TextStyle(font: bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Date', 'Invoice ID', 'Sale (BDT)', 'Profit (BDT)'],
                data:
                    entity.invoices
                        .map(
                          (inv) => [
                            DateFormat('dd-MMM-yyyy').format(inv.date),
                            inv.invoiceId,
                            inv.sale.toStringAsFixed(2),
                            inv.profit.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),

              pw.SizedBox(height: 30),

              // Totals
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Total Sales:  ${entity.totalSale.toStringAsFixed(2)} BDT",
                      style: pw.TextStyle(font: font, fontSize: 14),
                    ),
                    pw.Divider(),
                    pw.Text(
                      "Total Profit:  ${entity.totalProfit.toStringAsFixed(2)} BDT",
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: PdfColors.green700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Footer(
                title: pw.Text(
                  "Generated by G-TEL ERP System",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
