// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'debatorcontroller.dart';
import 'transaction.dart';

class Debatordetails extends StatelessWidget {
  final String id;
  final String name;

  Debatordetails({super.key, required this.id, required this.name});

  final controller = Get.find<DebatorController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: const Color(0xFF0C2E69),
        title: Text(
          name,
          style: TextStyle(fontSize: 18.sp, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 25.w),
            child: IconButton(
              icon: const FaIcon(FontAwesomeIcons.filePdf, color: Colors.white),
              onPressed: () => downloadPDF(id, name),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F3D85),
        onPressed: () => addTransactionDialog(controller, id),
        child: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
      ),

      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // SUMMARY CARD
            StreamBuilder(
              stream: controller.summary(id),
              builder: (_, snap) {
                if (!snap.hasData) return const SizedBox();

                final data = snap.data!;
                final balance = data['balance'] as double? ?? 0.0;
                final balanceLabel = balance >= 0 ? "Pending Bill" : "Shop Owes";
                final balanceColor = balance >= 0 ? Colors.red : Colors.green;

                return Container(
                  width: 750.w,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F3D85), Color(0xFF0A1F44)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      summaryItem(FontAwesomeIcons.arrowDown, "Credit", data['credit']),
                      summaryItem(FontAwesomeIcons.arrowUp, "Debit", data['debit']),
                      summaryItem(
                        FontAwesomeIcons.balanceScale,
                        balanceLabel,
                        balance.abs(),
                        valueColor: balanceColor,
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 16.h),

            // TRANSACTION LIST
            Expanded(
              child: StreamBuilder(
                stream: controller.loadTransactions(id),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (_, i) {
                      final t = docs[i].data() as Map;

                      DateTime tDate = t["date"] is DateTime
                          ? t["date"]
                          : (t["date"] as dynamic).toDate();

                      final formattedDate = DateFormat("dd MMM yyyy").format(tDate);

                      return  Padding(
  padding: EdgeInsets.symmetric(horizontal: 100.w, vertical: 20.h),
  child: Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F1FF), Color(0xFFDCEBFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 6,
          offset: const Offset(2, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        FaIcon(
          t['type'].toLowerCase() == 'credit'
              ? FontAwesomeIcons.arrowDown
              : FontAwesomeIcons.arrowUp,
          color: Colors.blueGrey,
          size: 18.sp,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${t['type'].toUpperCase()} - ${t['amount']} Tk",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: const Color(0xFF0C2E69),
                ),
              ),
              SizedBox(height: 4.h),
              // Payment method for debit transactions
              if (t['type'].toLowerCase() == 'debit' && t['paymentMethod'] != null)
                Text(
                  formatPaymentMethod(t['paymentMethod'] as Map),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.blueGrey,
                  ),
                ),
              if (t['note'] != null && t['note'] != '')
                Text(
                  t['note'],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.blueGrey,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.blueGrey,
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 18.sp),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Confirm Delete"),
                    content: const Text(
                        "Are you sure you want to delete this transaction? This will also remove the corresponding daily sale."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel")),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete")),
                    ],
                  ),
                );

                if (confirm == true) {
                  await controller.deleteTransaction(id, docs[i].id);
                }
              },
            ),
          ],
        ),
      ],
    ),
  ),
);

                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


Future<void> downloadPDF(String id, String name) async {
  final snap = await controller.db
      .collection("debatorbody")
      .doc(id)
      .collection("transactions")
      .orderBy("date")
      .get();

  // Map transactions safely
  List<Map<String, dynamic>> data = snap.docs.map((d) {
    final docData = d.data();
    DateTime tDate = docData["date"] is DateTime
        ? docData["date"]
        : (docData["date"] as dynamic).toDate();

    // Safe paymentMethod handling
    String paymentString = "";
    final pmField = docData.containsKey('paymentMethod') ? docData["paymentMethod"] : null;

    if (pmField != null) {
      if (pmField is Map) {
        if (pmField['type'] == 'bank') {
          paymentString =
              "Bank (${pmField['bankName']}, ${pmField['branch']}, A/C: ${pmField['accountNumber']})";
        } else {
          paymentString = pmField['type'] ?? "";
        }
      } else if (pmField is String) {
        paymentString = pmField;
      }
    }

    return {
      "date": DateFormat("dd MMM yyyy").format(tDate),
      "type": docData["type"] ?? "",
      "amount": (docData["amount"] as num?)?.toDouble() ?? 0.0,
      "note": docData["note"] ?? "",
      "paymentMethod": paymentString,
    };
  }).toList();

  // Generate PDF
  final pdfData = await controller.generatePDF(name, data);

  // Download in browser
  final blob = html.Blob([pdfData], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", "$name-transactions.pdf")
    ..click();
  html.Url.revokeObjectUrl(url);
}


}

Widget summaryItem(IconData icon, String title, dynamic value,
    {Color valueColor = Colors.white}) {
  return Column(
    children: [
      FaIcon(icon, color: Colors.white, size: 20.sp),
      SizedBox(height: 4.h),
      Text(title, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
      SizedBox(height: 2.h),
      Text(
        value.toStringAsFixed(2),
        style: TextStyle(
          color: valueColor,
          fontWeight: FontWeight.bold,
          fontSize: 14.sp,
        ),
      ),
    ],
  );
}

/// Helper to format payment method map
String formatPaymentMethod(Map pm) {
  if (pm['type'] == 'bank') {
    return "Payment Method: Bank (${pm['bankName']}, ${pm['branch']}, A/C: ${pm['accountNumber']})";
  } else {
    return "Payment Method: ${pm['type']}";
  }
}
