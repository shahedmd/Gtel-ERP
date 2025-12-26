// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import 'model.dart';

class StaffController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // Observables
  var isLoading = false.obs;
  var staffList = <StaffModel>[].obs;
  var filteredStaffList = <StaffModel>[].obs;
  var searchQuery = "".obs;

  @override
  void onInit() {
    super.onInit();
    loadStaff();
    // Listen to search query changes and update filtered list
    debounce(searchQuery, (_) => filterStaff(), time: const Duration(milliseconds: 300));
  }

  // --- STYLING CONSTANTS (Matched to Sidebar) ---
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkSlate = Color(0xFF111827);

  // ------------------------------------------------------------------
  // LOAD & FILTER STAFF
  // ------------------------------------------------------------------
  Future<void> loadStaff() async {
    try {
      isLoading.value = true;
      final snap = await db.collection("staff").orderBy("createdAt", descending: true).get();
      staffList.value = snap.docs.map((d) => StaffModel.fromFirestore(d)).toList();
      filteredStaffList.value = staffList;
    } catch (e) {
      Get.snackbar("Error", "Failed to load staff: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void filterStaff() {
    if (searchQuery.isEmpty) {
      filteredStaffList.value = staffList;
    } else {
      filteredStaffList.value = staffList
          .where((s) => s.name.toLowerCase().contains(searchQuery.value.toLowerCase()) || 
                        s.phone.contains(searchQuery.value))
          .toList();
    }
  }

  // ------------------------------------------------------------------
  // ADD STAFF
  // ------------------------------------------------------------------
  Future<void> addStaff({
    required String name,
    required String phone,
    required String nid,
    required String des,
    required int salary,
    required DateTime joinDate,
  }) async {
    try {
      await Get.showOverlay(
        asyncFunction: () async {
          await db.collection("staff").add({
            "name": name,
            "phone": phone,
            "nid": nid,
            "des": des,
            "salary": salary,
            "joiningDate": joinDate,
            "createdAt": FieldValue.serverTimestamp(),
          });
          await loadStaff();
          Get.snackbar("Success", "$name added to payroll", 
              backgroundColor: Colors.green, colorText: Colors.white);
        },
        loadingWidget: const Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    } catch (e) {
      Get.snackbar("Error", "Could not add staff: $e");
    }
  }

  // ------------------------------------------------------------------
  // SALARY OPERATIONS
  // ------------------------------------------------------------------
  Future<void> addSalary(String staffId, double amount, String note, String month, DateTime date) async {
    try {
      await Get.showOverlay(
        asyncFunction: () async {
          await db.collection("staff").doc(staffId).collection("salaries").add({
            "amount": amount,
            "note": note,
            "month": month,
            "date": date,
            "createdAt": FieldValue.serverTimestamp(),
          });
        },
        loadingWidget: const Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    } catch (e) {
      Get.snackbar("Payment Error", e.toString());
    }
  }

  Stream<List<SalaryModel>> streamSalaries(String staffId) {
    return db
        .collection("staff")
        .doc(staffId)
        .collection("salaries")
        .orderBy("date", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SalaryModel.fromFirestore(d)).toList());
  }

  // ------------------------------------------------------------------
  // PROFESSIONAL PDF GENERATOR
  // ------------------------------------------------------------------
  Future<Uint8List> generateProfessionalPDF(StaffModel staff, List<SalaryModel> salaries) async {
    final pdf = pw.Document();
    final totalPaid = salaries.fold(0.0, (sumvalue, item) => sumvalue + item.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("G-TEL ERP SYSTEM", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text("Staff Salary Statement", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
                  pw.Text("Ref: STF-${staff.id.substring(0, 5).toUpperCase()}"),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 2, color: PdfColors.blue900),
          pw.SizedBox(height: 20),

          // Staff Info Card
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Column(
              children: [
                _pdfRow("Employee Name:", staff.name),
                _pdfRow("Designation:", staff.des),
                _pdfRow("Base Salary:", "\$${staff.salary.toStringAsFixed(2)}"),
                _pdfRow("Phone:", staff.phone),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Salaries Table
          pw.Table.fromTextArray(
            headers: ["Month", "Date", "Note", "Amount Paid"],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            data: salaries.map((s) => [
              s.month,
              DateFormat('dd/MM/yy').format(s.date),
              s.note,
              "\$${s.amount.toStringAsFixed(2)}",
            ]).toList(),
          ),

          pw.SizedBox(height: 20),

          // Total Summary
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Total Accumulated:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text("\$${totalPaid.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Text(value),
        ],
      ),
    );
  }
}