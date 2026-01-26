// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'addsalary.dart';
import 'controller.dart';
import 'model.dart';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

const Color darkSlate = Color(0xFF111827);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF9FAFB);
const Color debtRed = Color(0xFFEF4444);
const Color creditGreen = Color(0xFF10B981);

class StaffDetailsPage extends StatelessWidget {
  final String staffId;
  final String name;

  StaffDetailsPage({super.key, required this.staffId, required this.name});

  final controller = Get.find<StaffController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkSlate),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Employee Profile: $name",
          style: const TextStyle(
            color: darkSlate,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // UPDATE 1: Edit Details Button
          IconButton(
            onPressed: () => _showEditDialog(context),
            icon: const Icon(Icons.edit, color: activeAccent),
            tooltip: "Edit Staff Details",
          ),
          const SizedBox(width: 10),
          // PDF Action
          TextButton.icon(
            onPressed: () => _handlePdfDownload(staffId),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              size: 16,
              color: Colors.redAccent,
            ),
            label: const Text(
              "Export Statement",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: activeAccent,
        onPressed: () => addSalaryDialog(controller, staffId, name),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "New Transaction",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSummary(),
            const SizedBox(height: 32),
            const Text(
              "Ledger History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
            const SizedBox(height: 16),
            _buildHistoryTable(),
          ],
        ),
      ),
    );
  }

  // --- EDIT DIALOG (UPDATE 1) ---
  void _showEditDialog(BuildContext context) {
    // 1. Get current data
    final staff = controller.staffList.firstWhere((s) => s.id == staffId);

    // 2. Controllers
    final nameC = TextEditingController(text: staff.name);
    final phoneC = TextEditingController(text: staff.phone);
    final nidC = TextEditingController(text: staff.nid);
    final desC = TextEditingController(text: staff.des);
    final salaryC = TextEditingController(text: staff.salary.toString());
    DateTime selectedDate = staff.joiningDate;

    // 3. Show Dialog
    Get.defaultDialog(
      title: "Edit Staff Details",
      contentPadding: const EdgeInsets.all(20),
      titleStyle: const TextStyle(
        color: darkSlate,
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneC,
              decoration: const InputDecoration(
                labelText: "Phone",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nidC,
              decoration: const InputDecoration(
                labelText: "NID Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desC,
              decoration: const InputDecoration(
                labelText: "Designation",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: salaryC,
              decoration: const InputDecoration(
                labelText: "Base Salary",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text("Joining Date: "),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) selectedDate = d;
                  },
                  child: const Text("Change Date"),
                ),
              ],
            ),
          ],
        ),
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: activeAccent),
        onPressed: () {
          if (nameC.text.isEmpty) return;
          controller.updateStaff(
            id: staffId,
            name: nameC.text,
            phone: phoneC.text,
            nid: nidC.text,
            des: desC.text,
            salary: int.tryParse(salaryC.text) ?? 0,
            joinDate: selectedDate,
          );
        },
        child: const Text(
          "Update Details",
          style: TextStyle(color: Colors.white),
        ),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text("Cancel"),
      ),
    );
  }

  // --- TOP SUMMARY SECTION (Quick Stats) ---
  Widget _buildInfoSummary() {
    return Obx(() {
      final staff = controller.staffList.firstWhere(
        (s) => s.id == staffId,
        orElse:
            () => StaffModel(
              id: '',
              name: '',
              phone: '',
              nid: '',
              des: '',
              salary: 0,
              joiningDate: DateTime.now(),
            ),
      );

      return StreamBuilder<List<SalaryModel>>(
        stream: controller.streamSalaries(staffId),
        builder: (context, snapshot) {
          double totalPaid = 0;
          if (snapshot.hasData) {
            totalPaid = snapshot.data!
                .where((item) => item.type == 'SALARY' || item.type == null)
                .fold(0.0, (sum, item) => sum + item.amount);
          }

          return Row(
            children: [
              _statCard(
                "Base Salary",
                "Tk ${staff.salary}",
                FontAwesomeIcons.moneyBillWave,
                activeAccent,
              ),
              const SizedBox(width: 16),
              _statCard(
                "Current Debt",
                "Tk ${(staff.currentDebt).toStringAsFixed(0)}",
                FontAwesomeIcons.handHoldingDollar,
                (staff.currentDebt) > 0 ? debtRed : creditGreen,
              ),
              const SizedBox(width: 16),
              _statCard(
                "Total Salary Paid",
                "Tk ${totalPaid.toStringAsFixed(0)}",
                FontAwesomeIcons.wallet,
                Colors.orange,
              ),
            ],
          );
        },
      );
    });
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: FaIcon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TABLE HISTORY ---
  Widget _buildHistoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: const BoxDecoration(
              color: darkSlate,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: _HeaderTxt("Date")),
                Expanded(flex: 2, child: _HeaderTxt("Type")),
                Expanded(flex: 2, child: _HeaderTxt("Month/Ref")),
                Expanded(flex: 3, child: _HeaderTxt("Note")),
                Expanded(flex: 2, child: _HeaderTxt("Amount")),
                SizedBox(width: 40),
              ],
            ),
          ),
          // Table Body
          StreamBuilder<List<SalaryModel>>(
            stream: controller.streamSalaries(staffId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text("No transaction history found.")),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder:
                    (context, index) => const Divider(height: 1, color: bgGrey),
                itemBuilder: (context, index) {
                  final t = snapshot.data![index];
                  return _buildTransactionRow(t);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(SalaryModel t) {
    String typeLabel = t.type ?? "SALARY";
    Color typeColor = activeAccent;
    Color bgColor = activeAccent.withOpacity(0.1);

    if (typeLabel == "ADVANCE") {
      typeColor = debtRed;
      bgColor = debtRed.withOpacity(0.1);
    } else if (typeLabel == "REPAYMENT") {
      typeColor = creditGreen;
      bgColor = creditGreen.withOpacity(0.1);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat("dd MMM yy").format(t.date),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              t.month,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              t.note.isEmpty ? "-" : t.note,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Tk ${t.amount.toStringAsFixed(0)}",
              style: TextStyle(fontWeight: FontWeight.bold, color: typeColor),
            ),
          ),

          // Delete Action
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _confirmDelete(t),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SalaryModel t) {
    Get.defaultDialog(
      title: "Confirm Deletion",
      middleText:
          "Are you sure you want to delete this record?\n\nDeleting an Advance/Repayment will automatically reverse the staff's debt balance.",
      textConfirm: "Delete & Reverse",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        try {
          final staffRef = controller.db.collection("staff").doc(staffId);
          await controller.db.runTransaction((transaction) async {
            final staffSnapshot = await transaction.get(staffRef);
            if (staffSnapshot.exists) {
              double currentDebt =
                  (staffSnapshot.data() as Map)['currentDebt']?.toDouble() ??
                  0.0;
              if (t.type == "ADVANCE") {
                transaction.update(staffRef, {
                  'currentDebt': currentDebt - t.amount,
                });
              } else if (t.type == "REPAYMENT") {
                transaction.update(staffRef, {
                  'currentDebt': currentDebt + t.amount,
                });
              }
            }
            final docRef = staffRef.collection("salaries").doc(t.id);
            transaction.delete(docRef);
          });
          await controller.loadStaff();
          Get.back();
          Get.snackbar(
            "Deleted",
            "Record removed and balance updated.",
            snackPosition: SnackPosition.BOTTOM,
          );
        } catch (e) {
          Get.back();
          Get.snackbar("Error", "Failed to delete: $e");
        }
      },
    );
  }

  Future<void> _handlePdfDownload(String staffId) async {
    try {
      final staff = controller.staffList.firstWhere((s) => s.id == staffId);
      final transactions = await controller.streamSalaries(staffId).first;
      final List<int> pdfData = await controller.generateProfessionalPDF(
        staff,
        transactions,
      );

      final Uint8List uint8list = Uint8List.fromList(pdfData);
      final JSUint8Array jsBytes = uint8list.toJS;
      final blobParts = [jsBytes].toJS as JSArray<web.BlobPart>;
      final blob = web.Blob(
        blobParts,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final String url = web.URL.createObjectURL(blob);
      final web.HTMLAnchorElement anchor =
          web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      anchor.download = "Ledger_${staff.name}_$timestamp.pdf";
      anchor.click();
      web.URL.revokeObjectURL(url);
    } catch (e) {
      debugPrint("Error generating PDF: $e");
      Get.snackbar("Error", "Could not generate PDF statement.");
    }
  }
}

class _HeaderTxt extends StatelessWidget {
  final String text;
  const _HeaderTxt(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}
