// ignore_for_file: deprecated_member_use, constant_identifier_names, curly_braces_in_flow_control_structures
import 'dart:typed_data';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpensecontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'model.dart';

enum StaffTransactionType { SALARY, ADVANCE, REPAYMENT, BONUS }

class StaffController extends GetxController {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ── Observables ────────────────────────────────────────────────────────────
  var isLoading = false.obs;
  var staffList = <StaffModel>[].obs;
  var filteredStaffList = <StaffModel>[].obs;
  var searchQuery = ''.obs;

  // Filter tab: 'all', 'active', 'resigned', 'suspended'
  var statusFilter = 'all'.obs;

  // ── Styling ─────────────────────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkSlate = Color(0xFF111827);

  @override
  void onInit() {
    super.onInit();
    loadStaff();
    debounce(
      searchQuery,
      (_) => filterStaff(),
      time: const Duration(milliseconds: 300),
    );
    ever(statusFilter, (_) => filterStaff());
  }

  // ── 1. LOAD & FILTER ───────────────────────────────────────────────────────
  Future<void> loadStaff() async {
    try {
      isLoading.value = true;
      final snap =
          await db
              .collection('staff')
              .orderBy('salary', descending: true)
              .get();
      staffList.value =
          snap.docs.map((d) => StaffModel.fromFirestore(d)).toList();
      filterStaff();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load staff: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void filterStaff() {
    var list = staffList.toList();

    // Status filter
    if (statusFilter.value != 'all') {
      list = list.where((s) => s.status == statusFilter.value).toList();
    }

    // Search filter
    final q = searchQuery.value.toLowerCase();
    if (q.isNotEmpty) {
      list =
          list
              .where(
                (s) => s.name.toLowerCase().contains(q) || s.phone.contains(q),
              )
              .toList();
    }

    filteredStaffList.value = list;
  }

  int get activeCount => staffList.where((s) => s.status == 'active').length;
  int get suspendedCount =>
      staffList.where((s) => s.status == 'suspended').length;
  int get resignedCount =>
      staffList.where((s) => s.status == 'resigned').length;

  // ── 2. ADD & EDIT STAFF ───────────────────────────────────────────────────
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
          await db.collection('staff').add({
            'name': name,
            'phone': phone,
            'nid': nid,
            'des': des,
            'salary': salary,
            'joiningDate': joinDate,
            'currentDebt': 0.0,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });
          await loadStaff();
          Get.snackbar(
            'Success',
            '$name added to payroll',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        },
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: primaryBlue),
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not add staff: $e');
    }
  }

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
      await db.collection('staff').doc(id).update({
        'name': name,
        'phone': phone,
        'nid': nid,
        'des': des,
        'salary': salary,
        'joiningDate': Timestamp.fromDate(joinDate),
      });
      await loadStaff();
      Get.back();
      Get.snackbar(
        'Updated',
        'Staff details updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Update failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── 3. DELETE STAFF ───────────────────────────────────────────────────────
  Future<void> deleteStaff(String staffId, String name) async {
    try {
      isLoading.value = true;
      // NOTE: Sub-collections (salaries, suspensions) are not auto-deleted
      // in client SDK. For production, use a Cloud Function or batch delete.
      await db.collection('staff').doc(staffId).delete();
      staffList.removeWhere((s) => s.id == staffId);
      filterStaff();
      Get.back(); // close detail page
      Get.snackbar(
        'Removed',
        '$name has been removed from the system',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Delete failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── 4. RESIGN STAFF ───────────────────────────────────────────────────────
  Future<void> resignStaff({
    required String staffId,
    required String name,
    required DateTime resignDate,
    required String reason,
  }) async {
    try {
      isLoading.value = true;
      await db.collection('staff').doc(staffId).update({
        'status': 'resigned',
        'resignDate': Timestamp.fromDate(resignDate),
        'resignReason': reason,
      });
      await loadStaff();
      Get.back();
      Get.snackbar(
        'Resigned',
        '$name has been marked as resigned',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not process resignation: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── 5. SUSPEND STAFF ──────────────────────────────────────────────────────
  Future<void> suspendStaff({
    required String staffId,
    required String staffName,
    required int days,
    required String month,
    required String reason,
  }) async {
    try {
      isLoading.value = true;

      // Check if a suspension already exists for this month
      final existing =
          await db
              .collection('staff')
              .doc(staffId)
              .collection('suspensions')
              .where('month', isEqualTo: month)
              .get();

      if (existing.docs.isNotEmpty) {
        // Update existing
        await existing.docs.first.reference.update({
          'days': days,
          'reason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new suspension record
        await db
            .collection('staff')
            .doc(staffId)
            .collection('suspensions')
            .add({
              'month': month,
              'days': days,
              'reason': reason,
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      // Mark staff as suspended
      await db.collection('staff').doc(staffId).update({'status': 'suspended'});

      await loadStaff();
      Get.back();
      Get.snackbar(
        'Suspended',
        '$staffName suspended for $days day(s) in $month',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not process suspension: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Lift suspension — set status back to active
  Future<void> liftSuspension(String staffId, String name) async {
    try {
      await db.collection('staff').doc(staffId).update({'status': 'active'});
      await loadStaff();
      Get.snackbar(
        'Lifted',
        'Suspension lifted for $name',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not lift suspension: $e');
    }
  }

  // ── 6. SUSPENSION STREAMS ─────────────────────────────────────────────────
  Stream<List<SuspensionModel>> streamSuspensions(String staffId) {
    return db
        .collection('staff')
        .doc(staffId)
        .collection('suspensions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => SuspensionModel.fromFirestore(d)).toList(),
        );
  }

  Future<SuspensionModel?> getSuspensionForMonth(
    String staffId,
    String month,
  ) async {
    final snap =
        await db
            .collection('staff')
            .doc(staffId)
            .collection('suspensions')
            .where('month', isEqualTo: month)
            .limit(1)
            .get();
    if (snap.docs.isEmpty) return null;
    return SuspensionModel.fromFirestore(snap.docs.first);
  }

  // ── 7. ADD TRANSACTION ────────────────────────────────────────────────────
  Future<void> addTransaction({
    required String staffId,
    required String staffName,
    required double amount,
    required String note,
    required DateTime date,
    required StaffTransactionType type,
    String? month,
    String paymentMethod = 'Cash',
  }) async {
    try {
      isLoading.value = true;
      final staffRef = db.collection('staff').doc(staffId);
      final transactionRef = staffRef.collection('salaries').doc();
      final String finalMonth = month ?? DateFormat('MMMM yyyy').format(date);

      await db.runTransaction((transaction) async {
        DocumentSnapshot staffSnap = await transaction.get(staffRef);
        if (!staffSnap.exists) throw 'Staff record not found!';

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
          'amount': amount,
          'note': note,
          'month': finalMonth,
          'date': Timestamp.fromDate(date),
          'type': type.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Expense / Cash Ledger allocation
      if (type == StaffTransactionType.SALARY ||
          type == StaffTransactionType.ADVANCE ||
          type == StaffTransactionType.BONUS) {
        if (Get.isRegistered<DailyExpensesController>()) {
          final dailyCtrl = Get.find<DailyExpensesController>();
          String expenseName = '';
          if (type == StaffTransactionType.SALARY) {
            expenseName = 'Salary: $staffName ($finalMonth)';
          } else if (type == StaffTransactionType.ADVANCE) {
            expenseName = 'Advance to $staffName';
          } else if (type == StaffTransactionType.BONUS) {
            expenseName = 'Festival/Bonus: $staffName ($finalMonth)';
          }
          await dailyCtrl.addDailyExpense(
            expenseName,
            amount.toDouble(),
            note: note,
            date: date,
          );
        }
      } else if (type == StaffTransactionType.REPAYMENT) {
        await db.collection('cash_ledger').add({
          'type': 'deposit',
          'amount': amount,
          'method': paymentMethod,
          'description': 'Loan Repayment from $staffName',
          'timestamp': Timestamp.fromDate(date),
          'source': 'staff_repayment',
        });
        if (Get.isRegistered<CashDrawerController>()) {
          Get.find<CashDrawerController>().fetchData();
        }
      }

      await loadStaff();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Success',
        'Transaction successful.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
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
        .collection('staff')
        .doc(staffId)
        .collection('salaries')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => SalaryModel.fromFirestore(d)).toList(),
        );
  }

  // ── 8. MONTHLY PAYROLL REPORT (suspension-aware) ──────────────────────────
  Future<void> downloadMonthlyPayroll(String month) async {
    isLoading.value = true;
    try {
      final pdf = pw.Document();
      double totalDisbursed = 0.0;
      double totalLiability = 0.0;
      double totalDeductions = 0.0;
      List<List<String>> reportData = [];

      for (var staff in staffList) {
        if (staff.isResigned) continue;

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

        // Check suspension for this month
        final suspension = await getSuspensionForMonth(staff.id, month);
        double effectiveSalary = staff.salary.toDouble();
        double deduction = 0.0;

        if (suspension != null) {
          effectiveSalary = suspension.adjustedSalary(staff.salary);
          deduction = suspension.deductionAmount(staff.salary);
          totalDeductions += deduction;
        }

        if (staff.salary > 0 || paidAmount > 0) {
          totalDisbursed += paidAmount;
          totalLiability += effectiveSalary;

          double due = effectiveSalary - paidAmount;
          if (due < 0) due = 0;

          String status =
              paidAmount >= effectiveSalary
                  ? 'PAID'
                  : paidAmount > 0
                  ? 'PARTIAL'
                  : 'UNPAID';

          reportData.add([
            staff.name,
            staff.des,
            staff.salary.toString(),
            deduction > 0 ? '(-${deduction.toStringAsFixed(0)})' : '-',
            effectiveSalary.toStringAsFixed(0),
            paidAmount.toStringAsFixed(0),
            due.toStringAsFixed(0),
            status,
          ]);
        }
      }

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
                            'MONTHLY PAYROLL SHEET',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          pw.Text(
                            'G-TEL ERP',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Period: $month',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _pdfStat(
                        'Total Commitment',
                        totalLiability.toStringAsFixed(0),
                      ),
                      _pdfStat(
                        'Total Deductions',
                        totalDeductions.toStringAsFixed(0),
                        color: PdfColors.orange,
                      ),
                      _pdfStat(
                        'Total Disbursed',
                        totalDisbursed.toStringAsFixed(0),
                        color: PdfColors.blue,
                      ),
                      _pdfStat(
                        'Pending Due',
                        (totalLiability - totalDisbursed).toStringAsFixed(0),
                        color: PdfColors.red,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Table.fromTextArray(
                  headers: [
                    'Staff Name',
                    'Desig.',
                    'Base Salary',
                    'Suspension (-)',
                    'Payable',
                    'Paid',
                    'Due',
                    'Status',
                  ],
                  data: reportData,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey900,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                    6: pw.Alignment.centerRight,
                    7: pw.Alignment.center,
                  },
                ),
                pw.Spacer(),
                pw.Text(
                  'Generated from G-TEL ERP',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
        ),
      );

      final Uint8List bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Payroll_$month.pdf',
      );
      Get.snackbar(
        'Success',
        'Payroll Report Generated',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Payroll generation failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  pw.Widget _pdfStat(String label, String value, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  // ── 9. INDIVIDUAL LEDGER PDF ──────────────────────────────────────────────
  Future<Uint8List> generateProfessionalPDF(
    StaffModel staff,
    List<SalaryModel> transactions,
  ) async {
    final pdf = pw.Document();
    double totalSalaryPaid = 0;
    double totalAdvanceTaken = 0;
    double totalBonusPaid = 0;

    for (var t in transactions) {
      if (t.type == 'ADVANCE') {
        totalAdvanceTaken += t.amount;
      } else if (t.type == 'BONUS') {
        totalBonusPaid += t.amount;
      } else if (t.type == 'SALARY' || t.type == null) {
        totalSalaryPaid += t.amount;
      }
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
                        'G-TEL ERP SYSTEM',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Staff Ledger Statement',
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
                      pw.Text('Date: $formattedDate'),
                      pw.Text(
                        'Ref: STF-${staff.id.substring(0, 5).toUpperCase()}',
                      ),
                      if (staff.isResigned)
                        pw.Text(
                          'STATUS: RESIGNED',
                          style: pw.TextStyle(
                            color: PdfColors.red,
                            fontWeight: pw.FontWeight.bold,
                          ),
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
                        _pdfRow('Employee:', staff.name),
                        _pdfRow('Designation:', staff.des),
                        _pdfRow('Phone:', staff.phone),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfRow('Base Salary:', '${staff.salary}'),
                        pw.Row(
                          children: [
                            pw.Text(
                              'Current Debt: ',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red,
                              ),
                            ),
                            pw.Text(
                              staff.currentDebt.toStringAsFixed(2),
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
                headers: ['Date', 'Type', 'Month/Ref', 'Note', 'Amount'],
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
                            s.type ?? 'SALARY',
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
                              'Total Salary Paid:',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              totalSalaryPaid.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        if (totalBonusPaid > 0) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Total Bonus Paid:',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.green900,
                                ),
                              ),
                              pw.Text(
                                totalBonusPaid.toStringAsFixed(2),
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.green900,
                                ),
                              ),
                            ],
                          ),
                        ],
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total Advances Taken:',
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
                              'Net Outflow:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              (totalSalaryPaid +
                                      totalAdvanceTaken +
                                      totalBonusPaid)
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

  // ── 10. BONUS SLIP & REPORT ───────────────────────────────────────────────
  Future<void> downloadBonusSlip(
    StaffModel staff,
    double amount,
    String month,
    String note,
    DateTime date,
  ) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5.landscape,
          margin: const pw.EdgeInsets.all(30),
          build:
              (context) => pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'G-TEL ERP',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        'FESTIVAL / BONUS SLIP',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfRow('Staff Name:', staff.name),
                            _pdfRow('Designation:', staff.des),
                            _pdfRow('Phone:', staff.phone),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Date: ${DateFormat('dd MMM yyyy').format(date)}',
                            ),
                            pw.Text('Period: $month'),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      color: PdfColors.grey100,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'BONUS AMOUNT:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${amount.toStringAsFixed(2)} BDT',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Narration / Note:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      note.isEmpty ? 'Bonus / Incentive' : note,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Spacer(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _signatureLine('Authorized By'),
                        _signatureLine('Receiver Signature'),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      );
      final Uint8List bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'BonusSlip_${staff.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not generate Bonus Slip: $e');
    }
  }

  Future<void> downloadMonthlyBonusReport(String month) async {
    isLoading.value = true;
    try {
      final pdf = pw.Document();
      double totalBonusDisbursed = 0.0;
      List<List<String>> reportData = [];

      for (var staff in staffList) {
        QuerySnapshot bonusSnap =
            await db
                .collection('staff')
                .doc(staff.id)
                .collection('salaries')
                .where('month', isEqualTo: month)
                .where('type', isEqualTo: 'BONUS')
                .get();

        double staffTotalBonus = 0.0;
        String notes = '';
        for (var doc in bonusSnap.docs) {
          staffTotalBonus += (doc['amount'] as num).toDouble();
          final n = doc['note']?.toString() ?? '';
          if (n.isNotEmpty) notes += notes.isEmpty ? n : ', $n';
        }

        if (staffTotalBonus > 0) {
          totalBonusDisbursed += staffTotalBonus;
          reportData.add([
            staff.name,
            staff.des,
            staff.phone,
            notes.isEmpty ? 'Bonus/Festival' : notes,
            staffTotalBonus.toStringAsFixed(0),
          ]);
        }
      }

      if (reportData.isEmpty) {
        Get.snackbar(
          'No Data',
          'No bonuses were given in $month',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        isLoading.value = false;
        return;
      }

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
                            'MONTHLY BONUS REPORT',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          pw.Text(
                            'G-TEL ERP',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Period: $month',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.amber700, width: 2),
                    color: PdfColors.amber50,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Bonus Disbursed:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${totalBonusDisbursed.toStringAsFixed(2)} BDT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Table.fromTextArray(
                  headers: [
                    'Staff Name',
                    'Designation',
                    'Phone',
                    'Note',
                    'Amount Paid',
                  ],
                  data: reportData,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.amber800,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerRight,
                  },
                ),
                pw.Spacer(),
                pw.Text(
                  'Generated from G-TEL ERP',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
        ),
      );

      final Uint8List bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'BonusReport_$month.pdf',
      );
      Get.snackbar(
        'Success',
        'Bonus Report Generated',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Report generation failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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

  pw.Widget _signatureLine(String label) {
    return pw.Container(
      width: 100,
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 1)),
      ),
      child: pw.Center(
        child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ),
    );
  }
}