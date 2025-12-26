// ignore_for_file: deprecated_member_use, avoid_types_as_parameter_names, unnecessary_cast

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonthlyExpenseModel {
  final String monthKey; // e.g., "Jan-2025"
  final int total;
  final List<DailySummary> items;

  MonthlyExpenseModel({
    required this.monthKey,
    required this.total,
    required this.items,
  });

  factory MonthlyExpenseModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return MonthlyExpenseModel(
      monthKey: id,
      total: (data['total'] as num?)?.toInt() ?? 0,
      items:
          (data['items'] as List? ?? [])
              .map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
    );
  }
}

class DailySummary {
  final String date; // e.g., "2025-12-27"
  int total;

  DailySummary({required this.date, required this.total});

  factory DailySummary.fromMap(Map<String, dynamic> map) => DailySummary(
    date: map['date'] ?? '',
    total: (map['total'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {'date': date, 'total': total};
}



class MonthlyExpensesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxList<MonthlyExpenseModel> monthlyList = <MonthlyExpenseModel>[].obs;
  final RxInt grandTotalAllMonths = 0.obs;
  final RxBool isLoading = false.obs;
  
  StreamSubscription? _monthlySubscription;

  @override
  void onInit() {
    super.onInit();
    fetchMonthlyExpenses();
  }

  @override
  void onClose() {
    _monthlySubscription?.cancel();
    super.onClose();
  }

  // ------------------------------------------------------------------
  // FETCH DATA (REAL-TIME)
  // ------------------------------------------------------------------
  void fetchMonthlyExpenses() {
    _monthlySubscription = _db
        .collection('monthly_expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final months = snapshot.docs
          .map((doc) => MonthlyExpenseModel.fromFirestore(doc.id, doc.data()))
          .toList();

      monthlyList.assignAll(months);
      grandTotalAllMonths.value = months.fold(0, (sum, m) => sum + m.total);
    });
  }

  // ------------------------------------------------------------------
  // ADD TO MONTHLY (ATOMIC TRANSACTION)
  // ------------------------------------------------------------------
  Future<void> addToMonthly({required int amount, required DateTime date}) async {
    final monthKey = "${DateFormat('MMM').format(date)}-${date.year}";
    final dayKey = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db.collection('monthly_expenses').doc(monthKey);

    return _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          'total': amount,
          'items': [{'date': dayKey, 'total': amount}],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        int currentTotal = (data['total'] ?? 0) as int;
        List<dynamic> itemsRaw = List.from(data['items'] ?? []);
        
        List<DailySummary> items = itemsRaw.map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e))).toList();
        
        int index = items.indexWhere((e) => e.date == dayKey);
        if (index >= 0) {
          items[index].total += amount;
        } else {
          items.add(DailySummary(date: dayKey, total: amount));
        }

        transaction.update(docRef, {
          'total': currentTotal + amount,
          'items': items.map((e) => e.toMap()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ------------------------------------------------------------------
  // REMOVE FROM MONTHLY (ATOMIC TRANSACTION)
  // ------------------------------------------------------------------
  Future<void> removeFromMonthly({required int amount, required DateTime date}) async {
    final monthKey = "${DateFormat('MMM').format(date)}-${date.year}";
    final dayKey = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db.collection('monthly_expenses').doc(monthKey);

    return _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      int currentTotal = (data['total'] ?? 0) as int;
      List<dynamic> itemsRaw = List.from(data['items'] ?? []);
      List<DailySummary> items = itemsRaw.map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e))).toList();

      int index = items.indexWhere((e) => e.date == dayKey);
      if (index >= 0) {
        items[index].total -= amount;
        // If daily total becomes 0 or less, remove the date entry
        if (items[index].total <= 0) items.removeAt(index);
        
        transaction.update(docRef, {
          'total': (currentTotal - amount).clamp(0, 999999999),
          'items': items.map((e) => e.toMap()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ------------------------------------------------------------------
  // PROFESSIONAL POS PDF REPORT
  // ------------------------------------------------------------------
  Future<void> generateMonthlyPDF(String monthKey) async {
    try {
      isLoading.value = true;
      final monthData = monthlyList.firstWhere((m) => m.monthKey == monthKey);
      
      final pdf = pw.Document();
      final primaryColor = PdfColors.blue900;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Branding Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("G-TEL ERP", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text("Monthly Expense Summary", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Statement Month: $monthKey", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: primaryColor, thickness: 1.5),
            pw.SizedBox(height: 20),

            // Daily Breakdown Table
            pw.Table.fromTextArray(
              headers: ['Date', 'Day Total (BDT)'],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
              data: monthData.items.map((e) => [
                DateFormat('dd MMM yyyy (EEEE)').format(DateTime.parse(e.date)),
                e.total.toStringAsFixed(2),
              ]).toList(),
            ),

            pw.SizedBox(height: 30),
            
            // Grand Total Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: primaryColor),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("MONTH TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("BDT ${monthData.total.toStringAsFixed(2)}", 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      Get.snackbar("Error", "Could not generate PDF: $e");
    } finally {
      isLoading.value = false;
    }
  }
}