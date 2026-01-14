// ignore_for_file: deprecated_member_use, constant_identifier_names
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Import your DailyExpensesController to automate expense recording
import 'model.dart';

// FUTURE PROOF: Enum to differentiate transaction types
enum StaffTransactionType {
  SALARY, // Regular Monthly Salary (Expense)
  ADVANCE, // Taking money as Loan (Expense + Increases Debt)
  REPAYMENT, // Paying back loan or Deduction (Income/Adjustment + Decreases Debt)
}

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
    debounce(
      searchQuery,
      (_) => filterStaff(),
      time: const Duration(milliseconds: 300),
    );
  }

  // --- STYLING CONSTANTS ---
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkSlate = Color(0xFF111827);

  // ------------------------------------------------------------------
  // 1. LOAD & FILTER STAFF
  // ------------------------------------------------------------------
  Future<void> loadStaff() async {
    try {
      isLoading.value = true;
      // Ordered by name or createdAt
      final snap =
          await db
              .collection("staff")
              .orderBy("createdAt", descending: true)
              .get();

      // We map the docs. Note: Ensure your StaffModel has a 'currentDebt' field.
      // If not, it will default to 0 via the model or map logic.
      staffList.value =
          snap.docs.map((d) => StaffModel.fromFirestore(d)).toList();
      filteredStaffList.value = staffList;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load staff: $e",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void filterStaff() {
    if (searchQuery.isEmpty) {
      filteredStaffList.value = staffList;
    } else {
      filteredStaffList.value =
          staffList
              .where(
                (s) =>
                    s.name.toLowerCase().contains(
                      searchQuery.value.toLowerCase(),
                    ) ||
                    s.phone.contains(searchQuery.value),
              )
              .toList();
    }
  }

  // ------------------------------------------------------------------
  // 2. ADD STAFF (Initialized with 0 Debt)
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
            "salary": salary, // Base Salary
            "joiningDate": joinDate,
            "currentDebt": 0.0, // NEW: Track how much they owe the company
            "createdAt": FieldValue.serverTimestamp(),
          });
          await loadStaff();
          Get.snackbar(
            "Success",
            "$name added to payroll",
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        },
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: primaryBlue),
        ),
      );
    } catch (e) {
      Get.snackbar("Error", "Could not add staff: $e");
    }
  }

  // ------------------------------------------------------------------
  // 3. ADD TRANSACTION (SALARY OR ADVANCE/DEBT) - UPGRADED
  // ------------------------------------------------------------------
  Future<void> addTransaction({
    required String staffId,
    required String staffName, // Needed for Daily Expense Title
    required double amount,
    required String note,
    required DateTime date,
    required StaffTransactionType type, // Enum: SALARY, ADVANCE, or REPAYMENT
    String? month, // Optional, mostly for Salary
  }) async {
    try {
      isLoading.value = true;

      final staffRef = db.collection("staff").doc(staffId);
      final transactionRef =
          staffRef
              .collection("salaries")
              .doc(); // Keeping collection name 'salaries' for legacy support, but it holds all types

      // A. ATOMIC TRANSACTION (Database Consistency)
      await db.runTransaction((transaction) async {
        DocumentSnapshot staffSnap = await transaction.get(staffRef);
        if (!staffSnap.exists) throw "Staff record not found!";

        // 1. Get current debt
        double currentDebt =
            (staffSnap.data() as Map)['currentDebt']?.toDouble() ?? 0.0;
        double newDebt = currentDebt;

        // 2. Calculate New Debt based on Type
        if (type == StaffTransactionType.ADVANCE) {
          newDebt = currentDebt + amount; // Taking money increases debt
        } else if (type == StaffTransactionType.REPAYMENT) {
          newDebt = currentDebt - amount; // Paying back decreases debt
        }
        // If SALARY, debt usually doesn't change unless you implement auto-deduction logic here.

        // 3. Update Staff Balance
        transaction.update(staffRef, {'currentDebt': newDebt});

        // 4. Add Transaction Record
        transaction.set(transactionRef, {
          "amount": amount,
          "note": note,
          "month": month ?? DateFormat('MMMM yyyy').format(date),
          "date": Timestamp.fromDate(date),
          "type": type.name, // Storing 'SALARY', 'ADVANCE', etc.
          "createdAt": FieldValue.serverTimestamp(),
        });
      });

      // B. INTEGRATION: Add to Daily Expenses (If money is leaving company)
      // Only for SALARY and ADVANCE. Repayment is money coming IN (or internal adjustment).
      if (type == StaffTransactionType.SALARY ||
          type == StaffTransactionType.ADVANCE) {
        if (Get.isRegistered<DailyExpensesController>()) {
          final dailyCtrl = Get.find<DailyExpensesController>();

          String expenseName =
              type == StaffTransactionType.SALARY
                  ? "Salary: $staffName ($month)"
                  : "Advance to $staffName";

          await dailyCtrl.addDailyExpense(
            expenseName,
            amount.toInt(),
            note: note,
            date: date,
          );
        }
      }

      // C. Refresh Data
      // We manually update the local list to reflect the debt change immediately without full reload if possible,
      // but loadStaff() is safer to ensure consistency.
      await loadStaff();

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Success",
        type == StaffTransactionType.ADVANCE
            ? "Advance recorded. Debt updated."
            : "Transaction successful.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Payment Error",
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Stream<List<SalaryModel>> streamSalaries(String staffId) {
    return db
        .collection("staff")
        .doc(staffId)
        .collection("salaries")
        .orderBy("date", descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => SalaryModel.fromFirestore(d)).toList(),
        );
  }

  // ------------------------------------------------------------------
  // 4. PROFESSIONAL PDF GENERATOR (UPGRADED)
  // ------------------------------------------------------------------
  // ------------------------------------------------------------------
  // 4. PROFESSIONAL PDF GENERATOR (CORRECTED)
  // Returns Uint8List so the UI can handle the download
  // ------------------------------------------------------------------
  Future<Uint8List> generateProfessionalPDF(
    StaffModel staff,
    List<SalaryModel> transactions,
  ) async {
    final pdf = pw.Document();

    // Calculate Totals
    double totalSalaryPaid = 0;
    double totalAdvanceTaken = 0;

    for (var t in transactions) {
      if (t.type == "ADVANCE") {
        totalAdvanceTaken += t.amount;
      } else if (t.type == "SALARY" || t.type == null) {
        totalSalaryPaid += t.amount;
      }
      // Repayments are ignored for "Total Paid out" calculation usually,
      // or you can handle them separately if needed.
    }

    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "G-TEL ERP SYSTEM",
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Staff Ledger Statement",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Date: $formattedDate"),
                      pw.Text(
                        "Ref: STF-${staff.id.substring(0, 5).toUpperCase()}",
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue900),
              pw.SizedBox(height: 15),

              // Staff Info Card
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfRow("Employee:", staff.name),
                        _pdfRow("Designation:", staff.des),
                        _pdfRow("Phone:", staff.phone),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfRow("Base Salary:", "${staff.salary}"),
                        pw.Row(
                          children: [
                            pw.Text(
                              "Current Debt: ",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red,
                              ),
                            ),
                            pw.Text(
                              (staff.currentDebt).toStringAsFixed(2),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Transactions Table
              pw.Table.fromTextArray(
                headers: ["Date", "Type", "Month/Ref", "Note", "Amount"],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                ),
                cellHeight: 25,
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                data:
                    transactions
                        .map(
                          (s) => [
                            DateFormat('dd/MM/yy').format(s.date),
                            s.type ?? "SALARY",
                            s.month,
                            s.note,
                            s.amount.toStringAsFixed(0),
                          ],
                        )
                        .toList(),
              ),

              pw.SizedBox(height: 20),

              // Total Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Total Salary Paid:",
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              totalSalaryPaid.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Total Advances Taken:",
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.red900,
                              ),
                            ),
                            pw.Text(
                              totalAdvanceTaken.toStringAsFixed(2),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.red900,
                              ),
                            ),
                          ],
                        ),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Net Outflow:",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              (totalSalaryPaid + totalAdvanceTaken)
                                  .toStringAsFixed(2),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Text(
                "Generated by System. No signature required.",
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
      ),
    );

    // CHANGED: Instead of Printing.layoutPdf(), we simply return the bytes.
    return pdf.save();
  } 

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
