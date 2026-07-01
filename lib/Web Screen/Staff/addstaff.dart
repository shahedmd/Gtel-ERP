// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'controller.dart';

const Color _kDark = Color(0xFF111827);
const Color _kBlue = Color(0xFF3B82F6);
const Color _kBg = Color(0xFFF3F4F6);

void addStaffDialog(StaffController controller) {
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final nidC = TextEditingController();
  final desC = TextEditingController();
  final salaryC = TextEditingController();
  final Rx<DateTime?> joiningDate = Rx<DateTime?>(null);

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = MediaQuery.of(context).size.width < 560;
          return Center(
            child: Container(
              width: isNarrow ? double.infinity : 500,
              margin:
                  isNarrow
                      ? const EdgeInsets.symmetric(horizontal: 12)
                      : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: _kDark,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.userPlus,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Register New Staff Member',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Personal Information'),
                          _buildField(
                            nameC,
                            'Full Name',
                            FontAwesomeIcons.user,
                          ),
                          const SizedBox(height: 12),
                          isNarrow
                              ? Column(
                                children: [
                                  _buildField(
                                    phoneC,
                                    'Phone Number',
                                    FontAwesomeIcons.phone,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildField(
                                    nidC,
                                    'NID Number',
                                    FontAwesomeIcons.idCard,
                                  ),
                                ],
                              )
                              : Row(
                                children: [
                                  Expanded(
                                    child: _buildField(
                                      phoneC,
                                      'Phone Number',
                                      FontAwesomeIcons.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildField(
                                      nidC,
                                      'NID Number',
                                      FontAwesomeIcons.idCard,
                                    ),
                                  ),
                                ],
                              ),
                          const SizedBox(height: 20),

                          _sectionLabel('Employment Details'),
                          _buildField(
                            desC,
                            'Designation / Role',
                            FontAwesomeIcons.briefcase,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            salaryC,
                            'Monthly Salary (BDT)',
                            FontAwesomeIcons.dollarSign,
                            type: TextInputType.number,
                          ),
                          const SizedBox(height: 12),

                          // Date picker
                          Obx(
                            () => InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: Get.context!,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder:
                                      (ctx, child) => Theme(
                                        data: ThemeData.light().copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: _kBlue,
                                          ),
                                        ),
                                        child: child!,
                                      ),
                                );
                                if (picked != null) {
                                  joiningDate.value = picked;
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _kBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(
                                  children: [
                                    const FaIcon(
                                      FontAwesomeIcons.calendarDay,
                                      size: 15,
                                      color: _kBlue,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      joiningDate.value != null
                                          ? 'Joining: ${DateFormat("dd MMMM yyyy").format(joiningDate.value!)}'
                                          : 'Select Joining Date',
                                      style: TextStyle(
                                        color:
                                            joiningDate.value != null
                                                ? _kDark
                                                : Colors.grey,
                                        fontWeight:
                                            joiningDate.value != null
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed:
                              () => _handleSave(
                                controller,
                                nameC,
                                phoneC,
                                nidC,
                                desC,
                                salaryC,
                                joiningDate,
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Confirm & Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    barrierDismissible: false,
  );
}

Widget _sectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: _kBlue,
        letterSpacing: 1,
      ),
    ),
  );
}

Widget _buildField(
  TextEditingController c,
  String hint,
  final dynamic icon, {
  TextInputType type = TextInputType.text,
}) {
  return TextField(
    controller: c,
    keyboardType: type,
    style: const TextStyle(fontSize: 14, color: _kDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      prefixIcon: FaIcon(icon, size: 15, color: Colors.grey),
      filled: true,
      fillColor: _kBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBlue, width: 1.5),
      ),
    ),
  );
}

void _handleSave(
  StaffController controller,
  TextEditingController name,
  TextEditingController phone,
  TextEditingController nid,
  TextEditingController des,
  TextEditingController salary,
  Rx<DateTime?> date,
) {
  if (name.text.isEmpty ||
      phone.text.isEmpty ||
      nid.text.isEmpty ||
      des.text.isEmpty ||
      salary.text.isEmpty ||
      date.value == null) {
    Get.snackbar(
      'Incomplete Form',
      'Please fill in all required fields.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return;
  }
  final parsedSalary = int.tryParse(salary.text);
  if (parsedSalary == null || parsedSalary <= 0) {
    Get.snackbar('Invalid Salary', 'Enter a valid numeric salary.');
    return;
  }
  controller.addStaff(
    name: name.text.trim(),
    phone: phone.text.trim(),
    nid: nid.text.trim(),
    des: des.text.trim(),
    salary: parsedSalary,
    joinDate: date.value!,
  );
  Get.back();
}
