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

class StaffDetailsPage extends StatelessWidget {
  final String staffId;
  final String name;

  StaffDetailsPage({super.key, required this.staffId, required this.name});

  final controller = Get.find<StaffController>();

  // Colors aligned with Sidebar
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);

  @override
  Widget build(BuildContext context) {
    // Find the specific staff member from the controller's list
    final staff = controller.staffList.firstWhere((s) => s.id == staffId);

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
          // Professional PDF Action
          TextButton.icon(
            onPressed: () => _handlePdfDownload(staff),
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
        label: const Text("Pay Salary", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSummary(staff),
            const SizedBox(height: 32),
            const Text(
              "Salary Payment History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
            const SizedBox(height: 16),
            _buildSalaryHistoryTable(),
          ],
        ),
      ),
    );
  }

  // --- TOP SUMMARY SECTION (Quick Stats) ---
  Widget _buildInfoSummary(dynamic staff) {
    return StreamBuilder<List<SalaryModel>>(
      stream: controller.streamSalaries(staffId),
      builder: (context, snapshot) {
        double totalPaid = 0;
        if (snapshot.hasData) {
          totalPaid = snapshot.data!.fold(
            0.0,
            (sum, item) => sum + item.amount,
          );
        }

        return Row(
          children: [
            _statCard(
              "Designation",
              staff.des,
              FontAwesomeIcons.userTag,
              activeAccent,
            ),
            const SizedBox(width: 16),
            _statCard(
              "Base Salary",
              "\$${staff.salary}",
              FontAwesomeIcons.moneyBillWave,
              Colors.green,
            ),
            const SizedBox(width: 16),
            _statCard(
              "Total Disbursed",
              "\$${totalPaid.toStringAsFixed(2)}",
              FontAwesomeIcons.wallet,
              Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: FaIcon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkSlate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- TABLE HISTORY ---
  Widget _buildSalaryHistoryTable() {
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
                Expanded(
                  flex: 2,
                  child: Text(
                    "Month",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Payment Date",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "Note",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Amount",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text("No payment history found."),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final salary = snapshot.data![index];
                  return _buildSalaryRow(salary);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(SalaryModel salary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              salary.month,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat("dd MMM yyyy").format(salary.date),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              salary.note.isEmpty ? "No note" : salary.note,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "\$${salary.amount}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: activeAccent,
              ),
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
              onPressed: () => _confirmDelete(salary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SalaryModel salary) {
    Get.defaultDialog(
      title: "Confirm Deletion",
      middleText:
          "Are you sure you want to remove the salary record for ${salary.month}?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        await controller.db
            .collection("staff")
            .doc(staffId)
            .collection("salaries")
            .doc(salary.id)
            .delete();
        Get.back();
        Get.snackbar(
          "Deleted",
          "Record removed successfully",
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }

  Future<void> _handlePdfDownload(dynamic staff) async {
    // 1. Get the current salaries (Assuming staffId is staff.id or similar)
    final salaries = await controller.streamSalaries(staff.id).first;

    // 2. Generate the PDF bytes
    final List<int> pdfData = await controller.generateProfessionalPDF(
      staff,
      salaries,
    );

    try {
      // 3. Convert List<int> to Uint8List
      final Uint8List uint8list = Uint8List.fromList(pdfData);

      // 4. Convert to JS-compatible types for WASM
      final JSUint8Array jsBytes = uint8list.toJS;

      // 5. Create the JSArray and cast it to the required BlobPart view
      final blobParts = [jsBytes].toJS as JSArray<web.BlobPart>;

      // 6. Create the Blob using package:web
      final blob = web.Blob(
        blobParts,
        web.BlobPropertyBag(type: 'application/pdf'),
      );

      // 7. Create the Object URL
      final String url = web.URL.createObjectURL(blob);

      // 8. Create Anchor Element and trigger download
      final web.HTMLAnchorElement anchor =
          web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;

      // Professional naming with unique timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      anchor.download = "Statement_${staff.name}_$timestamp.pdf";

      anchor.click();

      // 9. Clean up memory
      web.URL.revokeObjectURL(url);
    } catch (e) {
      debugPrint("Error generating or downloading PDF: $e");
      // Optional: show a user-friendly snackbar
      Get.snackbar("Download Error", "Could not generate the PDF statement.");
    }
  }
}
