// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'gteldebtorcontroller.dart';

// --- ERP Colors ---
const Color darkSlate = Color(0xFF0F172A);
const Color activeAccent = Color(0xFF2563EB);
const Color bgGrey = Color(0xFFF8FAFC);
const Color textMuted = Color(0xFF64748B);
const Color dangerRed = Color(0xFFDC2626);
const Color successGreen = Color(0xFF16A34A);

// ============================================================================
// 1. MEMORY-SAFE CONTROLLERS (GetX)
// ============================================================================

/// Safely holds state and controllers for a single dynamic payment method
class PaymentMethodState {
  final RxString type;
  final TextEditingController numC; // Handles bkash/nagad
  final TextEditingController bankNameC;
  final TextEditingController bankAccC;
  final TextEditingController bankBranchC;

  PaymentMethodState({String initialType = 'cash'})
    : type = initialType.obs,
      numC = TextEditingController(),
      bankNameC = TextEditingController(),
      bankAccC = TextEditingController(),
      bankBranchC = TextEditingController();

  void dispose() {
    numC.dispose();
    bankNameC.dispose();
    bankAccC.dispose();
    bankBranchC.dispose();
  }
}

/// Main controller for the Add Debtor Form
class AddDebtorFormController extends GetxController {
  final DebatorController mainCtrl;
  AddDebtorFormController(this.mainCtrl);

  final nameC = TextEditingController();
  final shopC = TextEditingController();
  final nidC = TextEditingController();
  final phoneC = TextEditingController();
  final addressC = TextEditingController();

  final RxList<PaymentMethodState> payments = <PaymentMethodState>[].obs;
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    addPaymentMethod(); // Start with one default cash method
  }

  @override
  void onClose() {
    // CRITICAL: Prevent Memory Leaks
    nameC.dispose();
    shopC.dispose();
    nidC.dispose();
    phoneC.dispose();
    addressC.dispose();
    for (var p in payments) {
      p.dispose();
    }
    super.onClose();
  }

  void addPaymentMethod() {
    payments.add(PaymentMethodState());
  }

  void removePaymentMethod(int index) {
    final p = payments[index];
    payments.removeAt(index);
    p.dispose(); // Clears RAM instantly when user clicks trash icon!
  }

  Future<void> save() async {
    if (nameC.text.trim().isEmpty ||
        phoneC.text.trim().isEmpty ||
        shopC.text.trim().isEmpty) {
      Get.snackbar(
        "Error",
        "Name, Shop, and Phone are required",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final List<Map<String, dynamic>> finalPayments = [];

      for (var p in payments) {
        final type = p.type.value;
        if (type == "cash") {
          finalPayments.add({"type": "cash", "currency": "BDT"});
        } else if (type == "bkash" || type == "nagad") {
          if (p.numC.text.trim().isEmpty) {
            throw "Please enter the ${type.capitalizeFirst} number.";
          }
          finalPayments.add({"type": type, "number": p.numC.text.trim()});
        } else if (type == "bank") {
          if (p.bankNameC.text.trim().isEmpty || p.bankAccC.text.trim().isEmpty) {
            throw "Bank Name and Account Number are required.";
          }
          finalPayments.add({
            "type": "bank",
            "bankName": p.bankNameC.text.trim(),
            "accountNumber": p.bankAccC.text.trim(),
            "branch": p.bankBranchC.text.trim(),
          });
        }
      }

      await mainCtrl.addBody(
        name: nameC.text,
        des: shopC.text,
        nid: nidC.text,
        phone: phoneC.text,
        address: addressC.text,
        payments: finalPayments,
      );
      // mainCtrl.addBody successfully triggers Get.back(), which calls onClose()
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }
}

// ============================================================================
// 2. DIALOG TRIGGER
// ============================================================================
void adddebatorDialog(DebatorController controller) {
  Get.dialog(
    GetBuilder<AddDebtorFormController>(
      init: AddDebtorFormController(controller),
      builder: (formCtrl) => _AddDebtorDialogUI(formCtrl: formCtrl),
    ),
    barrierDismissible: false,
  );
}

// ============================================================================
// 3. DIALOG UI (Stateless & Responsive)
// ============================================================================
class _AddDebtorDialogUI extends StatelessWidget {
  final AddDebtorFormController formCtrl;

  const _AddDebtorDialogUI({required this.formCtrl});

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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: activeAccent, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.userPlus,
                    color: Colors.white,
                    size: 18,
                  ),
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Identity Information"),

                    if (isMobile) ...[
                      _buildField(formCtrl.nameC, "Full Name", Icons.person),
                      const SizedBox(height: 12),
                      _buildField(
                        formCtrl.shopC,
                        "Shop/Organization",
                        Icons.store,
                      ),
                      const SizedBox(height: 12),
                      _buildField(formCtrl.nidC, "NID Number", Icons.badge),
                      const SizedBox(height: 12),
                      _buildField(formCtrl.phoneC, "Phone Number", Icons.phone),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              formCtrl.nameC,
                              "Full Name",
                              Icons.person,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              formCtrl.shopC,
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
                            child: _buildField(
                              formCtrl.nidC,
                              "NID Number",
                              Icons.badge,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              formCtrl.phoneC,
                              "Phone Number",
                              Icons.phone,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildField(
                      formCtrl.addressC,
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
                          onPressed: formCtrl.addPaymentMethod,
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
                        children: List.generate(formCtrl.payments.length, (
                          index,
                        ) {
                          return _buildPaymentCard(
                            formCtrl.payments[index],
                            index,
                            isMobile,
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- FOOTER ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: bgGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Obx(
                    () => TextButton(
                      onPressed:
                          formCtrl.isSubmitting.value ? null : () => Get.back(),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Obx(
                    () => ElevatedButton(
                      onPressed:
                          formCtrl.isSubmitting.value ? null : formCtrl.save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          formCtrl.isSubmitting.value
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
                                style: TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _buildPaymentCard(PaymentMethodState p, int index, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.payments, color: activeAccent, size: 20),
            title: Obx(
              () => DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: p.type.value,
                  isExpanded: true,
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
                  onChanged: (v) => p.type.value = v!,
                ),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: dangerRed,
                size: 20,
              ),
              onPressed: () => formCtrl.removePaymentMethod(index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Obx(() {
              final type = p.type.value;
              if (type == "cash") {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: successGreen, size: 16),
                       SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Cash on Delivery / Spot Payment enabled",
                          style: TextStyle(
                            color: successGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (type == "bkash" || type == "nagad") {
                return _buildField(
                  p.numC,
                  "${type.toUpperCase()} Account Number",
                  Icons.phone_android,
                );
              } else {
                return Column(
                  children: [
                    _buildField(
                      p.bankNameC,
                      "Bank Name",
                      Icons.account_balance,
                    ),
                    const SizedBox(height: 8),
                    if (isMobile) ...[
                      _buildField(p.bankAccC, "Account Number", Icons.numbers),
                      const SizedBox(height: 8),
                      _buildField(
                        p.bankBranchC,
                        "Branch (Optional)",
                        Icons.business,
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              p.bankAccC,
                              "Account Number",
                              Icons.numbers,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildField(
                              p.bankBranchC,
                              "Branch (Optional)",
                              Icons.business,
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              }
            }),
          ),
        ],
      ),
    );
  }
}
