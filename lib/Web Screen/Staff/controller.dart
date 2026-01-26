// ignore_for_file: deprecated_member_use, constant_identifier_names, avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web; // For Web Download

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'model.dart';

enum StaffTransactionType { SALARY, ADVANCE, REPAYMENT }

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
  // 1. LOAD & FILTER STAFF (UPDATED: SORT BY SALARY)
  // ------------------------------------------------------------------
  Future<void> loadStaff() async {
    try {
      isLoading.value = true;
      // UPDATE 3: Serial staff according to salary amount (Descending)
      final snap =
          await db
              .collection("staff")
              .orderBy("salary", descending: true)
              .get();

      staffList.value =
          snap.docs.map((d) => StaffModel.fromFirestore(d)).toList();
      filterStaff(); // Re-apply filter if any
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
  // 2. ADD & EDIT STAFF (UPDATED)
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
            "currentDebt": 0.0,
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

  // UPDATE 1: Edit Staff Method
  Future<void> updateStaff({
    required String id,
    required String name,
    required String phone,
    required String nid,
    required String des,
    required int salary,
    required DateTime joinDate,
  }) async {
    try {
      isLoading.value = true;
      await db.collection("staff").doc(id).update({
        "name": name,
        "phone": phone,
        "nid": nid,
        "des": des,
        "salary": salary,
        "joiningDate": Timestamp.fromDate(joinDate),
      });
      await loadStaff();
      Get.back(); // Close dialog
      Get.snackbar(
        "Updated",
        "Staff details updated successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 3. ADD TRANSACTION
  // ------------------------------------------------------------------
  Future<void> addTransaction({
    required String staffId,
    required String staffName,
    required double amount,
    required String note,
    required DateTime date,
    required StaffTransactionType type,
    String? month,
  }) async {
    try {
      isLoading.value = true;
      final staffRef = db.collection("staff").doc(staffId);
      final transactionRef = staffRef.collection("salaries").doc();

      await db.runTransaction((transaction) async {
        DocumentSnapshot staffSnap = await transaction.get(staffRef);
        if (!staffSnap.exists) throw "Staff record not found!";

        double currentDebt =
            (staffSnap.data() as Map)['currentDebt']?.toDouble() ?? 0.0;
        double newDebt = currentDebt;

        if (type == StaffTransactionType.ADVANCE) {
          newDebt = currentDebt + amount;
        } else if (type == StaffTransactionType.REPAYMENT) {
          newDebt = currentDebt - amount;
        }

        transaction.update(staffRef, {'currentDebt': newDebt});
        transaction.set(transactionRef, {
          "amount": amount,
          "note": note,
          "month": month ?? DateFormat('MMMM yyyy').format(date),
          "date": Timestamp.fromDate(date),
          "type": type.name,
          "createdAt": FieldValue.serverTimestamp(),
        });
      });

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
      await loadStaff();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Success",
        "Transaction successful.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
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

  // ... inside StaffController ...

  // ------------------------------------------------------------------
  // 4. MONTHLY PAYROLL REPORT (UPDATED WITH DUE CALCULATION)
  // ------------------------------------------------------------------
  Future<void> downloadMonthlyPayroll(String month) async {
    isLoading.value = true;
    try {
      final pdf = pw.Document();
      double totalDisbursed = 0.0;
      double totalLiability = 0.0;

      List<List<String>> reportData = [];

      // Loop through all staff
      for (var staff in staffList) {
        // Query logic: Get records where 'month' matches EXACTLY the string (e.g., "January 2026")
        // regardless of the actual created date.
        QuerySnapshot salarySnap =
            await db
                .collection('staff')
                .doc(staff.id)
                .collection('salaries')
                .where('month', isEqualTo: month)
                .where('type', isEqualTo: 'SALARY')
                .get();

        double paidAmount = 0.0;
        for (var doc in salarySnap.docs) {
          paidAmount += (doc['amount'] as num).toDouble();
        }

        // Only add to report if there is a salary defined or payment made
        if (staff.salary > 0 || paidAmount > 0) {
          totalDisbursed += paidAmount;
          totalLiability += staff.salary;

          double due = staff.salary - paidAmount;
          if (due < 0) due = 0; // Prevent negative if overpaid

          String status = "";

          if (paidAmount >= staff.salary) {
            status = "PAID";
          } else if (paidAmount > 0) {
            status = "PARTIAL";
          } else {
            status = "UNPAID";
          }

          reportData.add([
            staff.name,
            staff.des,
            staff.salary.toString(), // Base
            paidAmount.toStringAsFixed(0), // Paid
            due.toStringAsFixed(0), // Due
            status,
          ]);
        }
      }

      // Generate PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build:
              (context) => [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "MONTHLY PAYROLL SHEET",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          pw.Text(
                            "G-TEL ERP",
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        "Period: $month",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Summary Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text("Total Commitment"),
                          pw.Text(
                            totalLiability.toStringAsFixed(0),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text("Total Disbursed"),
                          pw.Text(
                            totalDisbursed.toStringAsFixed(0),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text("Pending Due"),
                          pw.Text(
                            (totalLiability - totalDisbursed).toStringAsFixed(
                              0,
                            ),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                pw.Table.fromTextArray(
                  headers: [
                    "Staff Name",
                    "Desig.",
                    "Base Salary",
                    "Paid",
                    "Due",
                    "Status",
                  ],
                  data: reportData,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey900,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.center,
                  },
                ),
                pw.Spacer(),
                pw.Text(
                  "Generated from G-TEL ERP",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
        ),
      );

      final Uint8List bytes = await pdf.save();
      _downloadWebPdf(bytes, "Payroll_$month.pdf");

      Get.snackbar(
        "Success",
        "Payroll Report Generated",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Payroll generation failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ------------------------------------------------------------------
  // 5. INDIVIDUAL LEDGER PDF
  // ------------------------------------------------------------------
  Future<Uint8List> generateProfessionalPDF(
    StaffModel staff,
    List<SalaryModel> transactions,
  ) async {
    final pdf = pw.Document();
    double totalSalaryPaid = 0;
    double totalAdvanceTaken = 0;

    for (var t in transactions) {
      if (t.type == "ADVANCE") {
        totalAdvanceTaken += t.amount;
      } else if (t.type == "SALARY" || t.type == null)
        // ignore: curly_braces_in_flow_control_structures
        totalSalaryPaid += t.amount;
    }

    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
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

  // Helper for Web Download
  void _downloadWebPdf(Uint8List data, String filename) {
    final JSUint8Array jsBytes = data.toJS;
    final blobParts = [jsBytes].toJS as JSArray<web.BlobPart>;
    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final String url = web.URL.createObjectURL(blob);
    final web.HTMLAnchorElement anchor =
        web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }
}
