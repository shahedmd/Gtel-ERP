// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'debatorcontroller.dart';

// Professional Slate ERP Colors
const Color darkSlate = Color(0xFF111827);
const Color activeAccent = Color(0xFF3B82F6);
const Color bgGrey = Color(0xFFF3F4F6);

void adddebatorDialog(DebatorController controller) {
  final nameC = TextEditingController();
  final shopC = TextEditingController();
  final nidC = TextEditingController();
  final phoneC = TextEditingController();
  final addressC = TextEditingController();

  // Reactive list for payments
  final payments = <Map<String, dynamic>>[].obs;

  // Function to create a new reactive payment object
  void addPaymentForm() {
    payments.add({
      "type": "cash".obs,
      "bkash": TextEditingController(),
      "nagad": TextEditingController(),
      "bankName": TextEditingController(),
      "bankAcc": TextEditingController(),
      "bankBranch": TextEditingController(),
    });
  }

  // Initialize with one payment method
  if (payments.isEmpty) addPaymentForm();

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 600, // Fixed width for a professional desktop feel
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            _buildHeader(),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Identity Information"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(nameC, "Full Name", Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            shopC,
                            "Shop/Organization",
                            Icons.store,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(nidC, "NID Number", Icons.badge),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            phoneC,
                            "Phone Number",
                            Icons.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      addressC,
                      "Permanent Address",
                      Icons.location_on,
                    ),

                    const SizedBox(height: 30),

                    // --- PAYMENT SECTION ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel("Saved Payment Methods"),
                        TextButton.icon(
                          onPressed: addPaymentForm,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add Method"),
                          style: TextButton.styleFrom(
                            foregroundColor: activeAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Obx(
                      () => Column(
                        children: List.generate(payments.length, (index) {
                          return _buildPaymentCard(payments, index, controller);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- FOOTER ---
            _buildFooter(
              controller,
              () => _handleSave(
                controller,
                nameC,
                shopC,
                nidC,
                phoneC,
                addressC,
                payments,
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// --- UI COMPONENTS ---

Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
        const SizedBox(width: 15),
        const Text(
          "Register New Debtor",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
        ),
      ],
    ),
  );
}

Widget _buildPaymentCard(
  RxList<Map<String, dynamic>> payments,
  int index,
  DebatorController controller,
) {
  var p = payments[index];
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: bgGrey,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black.withOpacity(0.05)),
    ),
    child: Column(
      children: [
        ListTile(
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.payments, color: activeAccent, size: 20),
          title: Obx(
            () => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: p["type"].value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                  fontSize: 13,
                ),
                items:
                    ["cash", "bkash", "nagad", "bank"]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged: (v) => p["type"].value = v!,
              ),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => payments.removeAt(index),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Obx(() {
            final type = p["type"].value;
            if (type == "cash") {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "Cash on Delivery / Spot Payment enabled",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            } else if (type == "bkash" || type == "nagad") {
              return _buildField(
                p[type],
                "${type.toUpperCase()} Account Number",
                Icons.phone_android,
              );
            } else {
              return Column(
                children: [
                  _buildField(
                    p["bankName"],
                    "Bank Name",
                    Icons.account_balance,
                  ),
                  const SizedBox(height: 8),
                  _buildField(p["bankAcc"], "Account Number", Icons.numbers),
                ],
              );
            }
          }),
        ),
      ],
    ),
  );
}

Widget _buildFooter(DebatorController controller, VoidCallback onSave) {
  return Container(
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
        const SizedBox(width: 16),
        Obx(
          () => ElevatedButton(
            onPressed: controller.isAddingBody.value ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                controller.isAddingBody.value
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      "Confirm & Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    ),
  );
}

// --- LOGIC HANDLER ---

Future<void> _handleSave(
  DebatorController controller,
  TextEditingController name,
  TextEditingController shop,
  TextEditingController nid,
  TextEditingController phone,
  TextEditingController address,
  RxList<Map<String, dynamic>> payments,
) async {
  // 1. Validation
  if (name.text.isEmpty || phone.text.isEmpty || shop.text.isEmpty) {
    Get.snackbar(
      "Error",
      "Required fields are missing",
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
    );
    return;
  }

  final List<Map<String, dynamic>> finalPayments = [];

  for (var p in payments) {
    final type = p["type"].value;
    if (type == "cash") {
      finalPayments.add({"type": "cash", "currency": "BDT"});
    } else if (type == "bkash" || type == "nagad") {
      finalPayments.add({"type": type, "number": p[type].text});
    } else if (type == "bank") {
      finalPayments.add({
        "type": "bank",
        "bankName": p["bankName"].text,
        "accountNumber": p["bankAcc"].text,
        "branch": p["bankBranch"].text,
      });
    }
  }

  await controller.addBody(
    name: name.text,
    des: shop.text,
    nid: nid.text,
    phone: phone.text,
    address: address.text,
    payments: finalPayments,
  );

  if (!controller.isAddingBody.value && (Get.isDialogOpen ?? false)) {
    // This only runs if the controller somehow missed the Get.back()
  }
}

// --- SHARED HELPERS ---

Widget _sectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: activeAccent,
        letterSpacing: 1.2,
      ),
    ),
  );
}

Widget _buildField(TextEditingController c, String hint, IconData icon) {
  return TextField(
    controller: c,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey),
      filled: true,
      fillColor: bgGrey,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
    ),
  );
}
