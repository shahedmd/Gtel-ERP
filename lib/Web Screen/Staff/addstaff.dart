import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'controller.dart';

const Color darkSlate = Color(0xFF111827);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF3F4F6);

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
      child: Container(
        width: 500, // Fixed width for a professional desktop feel
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(FontAwesomeIcons.userPlus, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  const Text(
                    "Register New Staff Member",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  )
                ],
              ),
            ),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Personal Information"),
                    _buildField(nameC, "Full Name", FontAwesomeIcons.user),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildField(phoneC, "Phone Number", FontAwesomeIcons.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(nidC, "NID Number", FontAwesomeIcons.idCard)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _sectionLabel("Employment Details"),
                    _buildField(desC, "Designation / Role", FontAwesomeIcons.briefcase),
                    const SizedBox(height: 12),
                    _buildField(salaryC, "Monthly Salary (Amount)", FontAwesomeIcons.dollarSign, type: TextInputType.number),
                    const SizedBox(height: 12),

                    // Date Picker Button
                    Obx(() => InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: Get.context!,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(primary: activeAccent),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) joiningDate.value = picked;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: bgGrey,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.calendarDay, size: 16, color: activeAccent),
                            const SizedBox(width: 12),
                            Text(
                              joiningDate.value != null
                                  ? "Joining Date: ${DateFormat("dd MMMM yyyy").format(joiningDate.value!)}"
                                  : "Select Joining Date",
                              style: TextStyle(
                                color: joiningDate.value != null ? darkSlate : Colors.grey,
                                fontWeight: joiningDate.value != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),

            // --- FOOTER ACTIONS ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: bgGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _handleSave(controller, nameC, phoneC, nidC, desC, salaryC, joiningDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Confirm & Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// --- HELPER COMPONENTS ---

Widget _sectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activeAccent, letterSpacing: 1.1),
    ),
  );
}

Widget _buildField(TextEditingController c, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
  return TextField(
    controller: c,
    keyboardType: type,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 16, color: Colors.grey),
      filled: true,
      fillColor: bgGrey,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: activeAccent, width: 1.5)),
    ),
  );
}

// --- LOGIC ---

void _handleSave(
  StaffController controller,
  TextEditingController name,
  TextEditingController phone,
  TextEditingController nid,
  TextEditingController des,
  TextEditingController salary,
  Rx<DateTime?> date,
) {
  if (name.text.isEmpty || phone.text.isEmpty || nid.text.isEmpty || des.text.isEmpty || salary.text.isEmpty || date.value == null) {
    Get.snackbar("Incomplete Form", "Please provide all required fields.",
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white);
    return;
  }

  final parsedSalary = int.tryParse(salary.text);
  if (parsedSalary == null) {
    Get.snackbar("Invalid Salary", "Please enter a valid numeric amount.");
    return;
  }

  controller.addStaff(
    name: name.text,
    phone: phone.text,
    nid: nid.text,
    des: des.text,
    salary: parsedSalary,
    joinDate: date.value!,
  );
  
  Get.back(); // Close dialog
}