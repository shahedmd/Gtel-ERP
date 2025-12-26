import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'controller.dart';

class PurchasePdf {
  /// Generate & preview PDF using GetX & printing (no path_provider)
  static Future<void> createAndPreview({
    required PurchaseController c,
  }) async {
    final pdf = pw.Document();

    // 🔹 Total amount
    final total = c.cart.fold<double>(
      0,
      (sum, i) => sum + (i.qty.value * i.product.sea),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ───────────── HEADER ─────────────
              pw.Text(
                'PURCHASE INVOICE',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text('Vendor: ${c.vendorNameC.text}'),
              pw.Text('Shop: ${c.shopNameC.text}'),
              pw.Text('Phone: ${c.phoneC.text}'),
              pw.Text('Date: ${DateTime.now()}'),

              pw.SizedBox(height: 20),

              // ───────────── TABLE ─────────────
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _cell('Model'),
                      _cell('Qty'),
                      _cell('Agent'),
                      _cell('Wholesale'),
                      _cell('AIR'),
                      _cell('SEA'),
                      _cell('Total'),
                    ],
                  ),
                  // Table rows
                  ...c.cart.map((e) {
                    final p = e.product;
                    final rowTotal = e.qty.value * p.sea;

                    return pw.TableRow(
                      children: [
                        _cell(p.model),
                        _cell(e.qty.value.toString()),
                        _cell(p.agent.toStringAsFixed(2)),
                        _cell(p.wholesale.toStringAsFixed(2)),
                        _cell(p.air.toStringAsFixed(2)),
                        _cell(p.sea.toStringAsFixed(2)),
                        _cell(rowTotal.toStringAsFixed(2)),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // ───────────── TOTAL ─────────────
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total: ৳ ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // ───────────── PREVIEW ─────────────
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }

  // ───────────── TABLE CELL ─────────────
  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text),
    );
  }
}