import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import '../local_purchase_page.dart';

// ─────────────────────────────────────────────────────────────
// AddSupplierDialog
// ─────────────────────────────────────────────────────────────
class AddSupplierDialog extends StatefulWidget {
  final DebatorController debtorCtrl;

  const AddSupplierDialog({super.key, required this.debtorCtrl});

  @override
  State<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<AddSupplierDialog> {
  late TextEditingController nameC, shopC, nidC, phoneC, addressC;
  final RxList<Map<String, dynamic>> payments =
      <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController();
    shopC = TextEditingController();
    nidC = TextEditingController();
    phoneC = TextEditingController();
    addressC = TextEditingController();
    _addPayment(); // default cash
  }

  @override
  void dispose() {
    for (final c in [nameC, shopC, nidC, phoneC, addressC]) {
      c.dispose();
    }
    for (final p in payments) {
      (p['bkash'] as TextEditingController).dispose();
      (p['nagad'] as TextEditingController).dispose();
      (p['bankName'] as TextEditingController).dispose();
      (p['bankAcc'] as TextEditingController).dispose();
      (p['bankBranch'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addPayment() {
    payments.add({
      'type': 'cash'.obs,
      'bkash': TextEditingController(),
      'nagad': TextEditingController(),
      'bankName': TextEditingController(),
      'bankAcc': TextEditingController(),
      'bankBranch': TextEditingController(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: darkSlate,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.userPlus,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 15),
                  const Text(
                    'Register New Supplier',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('IDENTITY INFORMATION'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _Field(nameC, 'Full Name',
                              Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _Field(shopC, 'Company/Shop',
                              Icons.store)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _Field(nidC, 'NID / Trade Lic.',
                              Icons.badge)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _Field(phoneC, 'Phone Number',
                              Icons.phone)),
                    ]),
                    const SizedBox(height: 12),
                    _Field(addressC, 'Permanent Address',
                        Icons.location_on),
                    const SizedBox(height: 30),

                    // Payment methods
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel('PAYMENT METHODS'),
                        TextButton.icon(
                          onPressed: _addPayment,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Method'),
                          style: TextButton.styleFrom(
                              foregroundColor: activeAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(() => Column(
                          children: List.generate(
                            payments.length,
                            (i) => _PaymentMethodCard(
                              paymentData: payments[i],
                              onDelete: () =>
                                  payments.removeAt(i),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // Footer
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
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 16),
                  Obx(() => ElevatedButton(
                        onPressed:
                            widget.debtorCtrl.isAddingBody.value
                                ? null
                                : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                        child: widget.debtorCtrl.isAddingBody.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Text('Confirm & Save',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (nameC.text.isEmpty ||
        phoneC.text.isEmpty ||
        shopC.text.isEmpty) {
      Get.snackbar('Error', 'Required fields are missing',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
      return;
    }

    final finalPayments = <Map<String, dynamic>>[];
    for (final p in payments) {
      final type = (p['type'] as RxString).value;
      if (type == 'cash') {
        finalPayments.add({'type': 'cash', 'currency': 'BDT'});
      } else if (type == 'bkash' || type == 'nagad') {
        finalPayments.add({
          'type': type,
          'number': (p[type] as TextEditingController).text,
        });
      } else if (type == 'bank') {
        finalPayments.add({
          'type': 'bank',
          'bankName': (p['bankName'] as TextEditingController).text,
          'accountNumber':
              (p['bankAcc'] as TextEditingController).text,
          'branch':
              (p['bankBranch'] as TextEditingController).text,
        });
      }
    }

    await widget.debtorCtrl.addBody(
      name: nameC.text,
      des: shopC.text,
      nid: nidC.text,
      phone: phoneC.text,
      address: addressC.text,
      payments: finalPayments,
    );

    Get.back();
    Get.snackbar('Success', 'Supplier Created Successfully.',
        backgroundColor: darkSlate, colorText: Colors.white);
  }
}

// ─────────────────────────────────────────────────────────────
// Payment Method Card
// ─────────────────────────────────────────────────────────────
class _PaymentMethodCard extends StatelessWidget {
  final Map<String, dynamic> paymentData;
  final VoidCallback onDelete;

  const _PaymentMethodCard({
    required this.paymentData,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.payments,
                color: activeAccent, size: 20),
            title: Obx(() => DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: paymentData['type'].value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                      fontSize: 13,
                    ),
                    items: ['cash', 'bkash', 'nagad', 'bank']
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        paymentData['type'].value = v!,
                  ),
                )),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: onDelete,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
                left: 16, right: 16, bottom: 16),
            child: Obx(() {
              final type = paymentData['type'].value;
              if (type == 'cash') {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Cash Payment enabled',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              } else if (type == 'bkash' || type == 'nagad') {
                return _Field(
                  paymentData[type] as TextEditingController,
                  '${type.toUpperCase()} Account Number',
                  Icons.phone_android,
                );
              } else {
                return Column(children: [
                  _Field(paymentData['bankName']
                      as TextEditingController,
                      'Bank Name', Icons.account_balance),
                  const SizedBox(height: 8),
                  _Field(paymentData['bankAcc']
                      as TextEditingController,
                      'Account Number', Icons.numbers),
                ]);
              }
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: activeAccent,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;

  const _Field(this.ctrl, this.hint, this.icon);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            Icon(icon, size: 18, color: Colors.blueGrey),
        filled: true,
        fillColor: bgGrey,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16),
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
}