// ignore_for_file: deprecated_member_use, file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'addstaff.dart';
import 'details.dart';

class StaffListPage extends StatelessWidget {
  final StaffController controller = Get.put(StaffController());

  // Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  StaffListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTableHead(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: activeAccent),
                );
              }

              if (controller.filteredStaffList.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                itemCount: controller.filteredStaffList.length,
                itemBuilder: (context, index) {
                  final staff = controller.filteredStaffList[index];
                  return _buildStaffRow(staff);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- HEADER SECTION (UPDATED) ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Staff Directory",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              // UPDATE 1: SHOW TOTAL MONTHLY PAYROLL LIABILITY
              Obx(() {
                // Calculate total of 'salary' field from all staff
                int totalLiability = controller.staffList.fold(
                  0,
                  (sum, item) => sum + item.salary,
                );
                return Text(
                  "Total Monthly Payroll: Tk ${NumberFormat.decimalPattern().format(totalLiability)}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: activeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }),
            ],
          ),
          const Spacer(),

          // Monthly Report Button
          OutlinedButton.icon(
            onPressed: () => _pickMonthAndDownload(context),
            icon: const FaIcon(
              FontAwesomeIcons.filePdf,
              size: 16,
              color: Colors.redAccent,
            ),
            label: const Text(
              "Payroll Report",
              style: TextStyle(color: Colors.redAccent),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Search Bar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: bgGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              onChanged: (val) => controller.searchQuery.value = val,
              decoration: const InputDecoration(
                hintText: "Search staff...",
                prefixIcon: Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Add Staff Button
          ElevatedButton.icon(
            onPressed: () => addStaffDialog(controller),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Add Member",
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickMonthAndDownload(BuildContext context) async {
    DateTime selectedDate = DateTime.now();
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        // Simple Month Picker Dialog
        return AlertDialog(
          title: const Text("Select Payroll Month"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "This report includes all payments tagged with the selected month, regardless of the actual payment date.",
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 300,
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  onDateChanged: (DateTime date) {
                    selectedDate = date;
                  },
                  initialCalendarMode: DatePickerMode.year,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Get.back(),
            ),
            ElevatedButton(
              child: const Text("Download Report"),
              onPressed: () {
                Get.back();
                // Formats to "January 2024" etc.
                String monthName = DateFormat('MMMM yyyy').format(selectedDate);
                controller.downloadMonthlyPayroll(monthName);
              },
            ),
          ],
        );
      },
    );
  }

  // --- TABLE HEADER ---
  Widget _buildTableHead() {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "Employee",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Designation",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Phone",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Joining Date",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Salary",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 50),
        ],
      ),
    );
  }

  // --- STAFF DATA ROW ---
  Widget _buildStaffRow(dynamic staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: InkWell(
        onTap:
            () => Get.to(
              () => StaffDetailsPage(staffId: staff.id, name: staff.name),
            ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildAvatar(staff.name),
                  const SizedBox(width: 12),
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: darkSlate,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  staff.des,
                  style: const TextStyle(
                    color: activeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                staff.phone,
                style: const TextStyle(color: textMuted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                DateFormat("dd MMM yyyy").format(staff.joiningDate),
                style: const TextStyle(color: textMuted),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                "\$${staff.salary}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: activeAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: const TextStyle(
            color: activeAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.usersSlash,
            size: 50,
            color: textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "No staff members found",
            style: TextStyle(color: textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
