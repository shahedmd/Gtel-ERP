import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AssetService {
  // Reference to Firestore Collection
  final CollectionReference _assetsCollection = FirebaseFirestore.instance
      .collection('fixed_assets');

  // --- 1. Add Asset to Firestore ---
  Future<void> addAsset({
    required String name,
    required String category,
    required double cost,
  }) async {
    await _assetsCollection.add({
      'name': name,
      'category': category,
      'cost': cost,
      'date': Timestamp.now(),
    });
  }

  // --- 2. Get Real-time Stream ---
  Stream<QuerySnapshot> getAssetsStream() {
    return _assetsCollection.orderBy('date', descending: true).snapshots();
  }

  // --- 3. PDF Export Logic ---
  // We pass the list of documents directly from the UI to this function
  Future<void> exportPdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    // Calculate Total for PDF
    double totalValuation = docs.fold(
      0,
      (sumv, doc) => sumv + (doc['cost'] as num).toDouble(),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Fixed Asset Overview',
                      style: pw.TextStyle(font: boldFont, fontSize: 24),
                    ),
                    pw.Text(
                      DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      style: pw.TextStyle(font: font),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // ignore: deprecated_member_use
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: font),
                data: <List<String>>[
                  <String>['Asset Name', 'Category', 'Date', 'Cost'],
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['date'] as Timestamp).toDate();
                    return [
                      data['name'] ?? '',
                      data['category'] ?? '',
                      DateFormat('MMM dd, yyyy').format(date),
                      NumberFormat.simpleCurrency().format(data['cost'] ?? 0),
                    ];
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Valuation: ${NumberFormat.simpleCurrency().format(totalValuation)}',
                    style: pw.TextStyle(font: boldFont, fontSize: 16),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Asset_Report.pdf',
    );
  }
}
