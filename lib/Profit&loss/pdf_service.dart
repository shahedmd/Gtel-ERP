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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Monthly Sales Report",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(dateLabel),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                "User/Agent Name: ${entity.name}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text("Phone/ID: ${entity.id}"),
              pw.SizedBox(height: 20),

              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Date', 'Invoice ID', 'Sale Amount', 'Profit'],
                data:
                    entity.invoices
                        .map(
                          (inv) => [
                            DateFormat('dd-MM-yyyy').format(inv.date),
                            inv.invoiceId,
                            inv.sale.toStringAsFixed(2),
                            inv.profit.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
              ),

              pw.SizedBox(height: 30),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Total Sales: \$${entity.totalSale.toStringAsFixed(2)}",
                    ),
                    pw.Divider(height: 100),
                    pw.Text(
                      "Total Profit: \$${entity.totalProfit.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
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
