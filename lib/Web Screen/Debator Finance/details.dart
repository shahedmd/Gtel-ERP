// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'debatorcontroller.dart';
import 'transaction.dart'; // addTransactionDialog
import 'model.dart';
import 'dart:js_interop'; // Required for .toJS conversion
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class Debatordetails extends StatelessWidget {
  final String id;
  final String name;

  Debatordetails({super.key, required this.id, required this.name});

  final controller = Get.find<DebatorController>();

  // ERP Theme Colors
  static const Color darkSlate = Color(0xFF111827);
  static const Color activeAccent = Color(0xFF3B82F6);
  static const Color bgGrey = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    // Find the current debtor model from controller for editing
    final debtor = controller.bodies.firstWhere((element) => element.id == id);

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkSlate),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: darkSlate,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              "Customer Ledger Account",
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Edit Profile Button
          _actionButton(
            icon: Icons.edit_note,
            label: "Edit Profile",
            color: activeAccent,
            onTap: () => _showEditProfileDialog(debtor),
          ),
          const SizedBox(width: 12),
          // PDF Statement Button
          _actionButton(
            icon: FontAwesomeIcons.filePdf,
            label: "Export Statement",
            color: Colors.redAccent,
            onTap: () => downloadPDF(id, name),
          ),
          const SizedBox(width: 24),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: activeAccent,
        onPressed: () => addTransactionDialog(controller, id),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "New Entry",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- ANALYTICS SUMMARY CARDS ---
            StreamBuilder<Map<String, dynamic>>(
              stream: controller.summary(id),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final data = snap.data!;
                return _buildSummaryRow(data);
              },
            ),

            const SizedBox(height: 32),

            // --- TRANSACTION TABLE ---
            _buildTableSection(),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: FaIcon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(Map<String, dynamic> data) {
    final balance = data['balance'] as double;
    return Row(
      children: [
        _statCard(
          "Total Credit (Purchased)",
          data['credit'],
          FontAwesomeIcons.fileInvoiceDollar,
          darkSlate,
        ),
        const SizedBox(width: 16),
        _statCard(
          "Total Debit (Paid)",
          data['debit'],
          FontAwesomeIcons.handHoldingDollar,
          Colors.green,
        ),
        const SizedBox(width: 16),
        _statCard(
          balance >= 0 ? "Current Due" : "Advance Balance",
          balance.abs(),
          FontAwesomeIcons.scaleBalanced,
          balance >= 0 ? Colors.redAccent : Colors.blue,
        ),
      ],
    );
  }

  Widget _statCard(String label, double value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
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
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
                Text(
                  "Tk ${value.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Transaction Audit Trail",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: darkSlate,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              // Table Header
              _tableHeader(),
              // Table Body
              StreamBuilder(
                stream: controller.loadTransactions(id),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final docs = snap.data!.docs;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _tableRow(docs[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeader() {
    return Container(
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
              "Date",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Transaction Type",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Note / Method",
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
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              "Actions",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(DocumentSnapshot doc) {
    final t = doc.data() as Map<String, dynamic>;
    final DateTime tDate = (t["date"] as Timestamp).toDate();
    final bool isCredit = t['type'].toString().toLowerCase() == 'credit';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat("dd MMM yyyy").format(tDate),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.red : Colors.green,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  t['type'].toString().toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.red : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t['paymentMethod'] != null)
                  Text(
                    formatPaymentMethod(t['paymentMethod'] as Map),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  t['note'] ?? "-",
                  style: const TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Tk ${t['amount']}",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkSlate,
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed:
                      () => _confirmDelete(t['transactionId'], t['amount'].toString()),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: activeAccent,
                    size: 18,
                  ),
                  onPressed:
                      () => editTransactionDialog(
                        controller,
                        id,
                        TransactionModel.fromFirestore(doc),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIC FUNCTIONS ---

  void _confirmDelete(String txId, String amount) {
    Get.defaultDialog(
      title: "Confirm Reversal",
      middleText:
          "Delete transaction of Tk $amount? This will also revert linked sales.",
      textConfirm: "Confirm Delete",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        Get.back();
        await controller.deleteTransaction(id, txId);
      },
    );
  }

  void _showEditProfileDialog(DebtorModel debtor) {
    // We reuse the styling of our add dialog but fill it with current data
    final nameC = TextEditingController(text: debtor.name);
    final shopC = TextEditingController(text: debtor.des);
    final phoneC = TextEditingController(text: debtor.phone);
    final nidC = TextEditingController(text: debtor.nid);
    final addressC = TextEditingController(text: debtor.address);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Debtor Profile",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 20),
              _buildField(nameC, "Full Name", Icons.person),
              const SizedBox(height: 12),
              _buildField(shopC, "Shop/Designation", Icons.store),
              const SizedBox(height: 12),
              _buildField(phoneC, "Phone", Icons.phone),
              const SizedBox(height: 12),
              _buildField(nidC, "NID", Icons.badge),
              const SizedBox(height: 12),
              _buildField(addressC, "Address", Icons.location_on),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeAccent,
                    ),
                    onPressed: () async {
                      await controller.editDebtor(
                        id: id,
                        oldName: debtor.name, // Used for syncing sales
                        newName: nameC.text,
                        des: shopC.text,
                        nid: nidC.text,
                        phone: phoneC.text,
                        address: addressC.text,
                        payments: debtor.payments,
                      );
                      Get.back();
                    },
                    child: const Text(
                      "Update Profile",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, size: 18, color: textMuted),
        filled: true,
        fillColor: bgGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void editTransactionDialog(
    DebatorController controller,
    String debtorId,
    TransactionModel tx,
  ) {
    final amountC = TextEditingController(text: tx.amount.toString());
    final noteC = TextEditingController(text: tx.note);
    final RxString selectedType = tx.type.obs;
    final Rx<DateTime> selectedDate = tx.date.obs;

    final debtor = controller.bodies.firstWhere((d) => d.id == debtorId);

    // --- THE FIX START ---
    final Rx<Map<String, dynamic>?> selectedPayment = Rx<Map<String, dynamic>?>(
      null,
    );

    if (tx.paymentMethod != null) {
      selectedPayment.value = debtor.payments.firstWhereOrNull((p) {
        // Compare the actual content of the maps
        return p['type'] == tx.paymentMethod?['type'] &&
            p['number'] == tx.paymentMethod?['number'] &&
            p['accountNumber'] == tx.paymentMethod?['accountNumber'];
      });
    }

    // Fallback: If no match found, use the first available payment method
    if (selectedPayment.value == null && debtor.payments.isNotEmpty) {
      selectedPayment.value = debtor.payments.first;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildDialogHeader(
                  "Edit Entry: ${DateFormat('dd MMM').format(tx.date)}",
                ),

                if (controller.gbIsLoading.value)
                  const LinearProgressIndicator(color: activeAccent),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Modify Transaction"),
                      _buildFieldd(
                        amountC,
                        "New Amount",
                        FontAwesomeIcons.coins,
                      ),
                      const SizedBox(height: 12),
                      _buildFieldd(
                        noteC,
                        "Edit Note",
                        FontAwesomeIcons.penToSquare,
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _typeDropdown(selectedType)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPaymentDropdown(
                              debtor.payments,
                              selectedPayment,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Footer Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed:
                                controller.gbIsLoading.value
                                    ? null
                                    : () async {
                                      await controller.editTransaction(
                                        debtorId: debtorId,
                                        transactionId: tx.id,
                                        oldAmount: tx.amount,
                                        newAmount:
                                            double.tryParse(amountC.text) ?? 0,
                                        oldType: tx.type,
                                        newType: selectedType.value,
                                        note: noteC.text,
                                        date: selectedDate.value,
                                        paymentMethod: selectedPayment.value,
                                      );
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  selectedType.value == 'credit'
                                      ? creditRed
                                      : debitGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 18,
                              ),
                            ),
                            child: const Text(
                              "Update Record",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ... inside your class

  Future<void> downloadPDF(String id, String name) async {
    // 1. Fetch data from Firebase
    final snap =
        await controller.db
            .collection("debatorbody")
            .doc(id)
            .collection("transactions")
            .orderBy("date")
            .get();

    List<Map<String, dynamic>> data =
        snap.docs.map((d) {
          final docData = d.data();
          return {
            "date": (docData["date"] as Timestamp).toDate(),
            "type": docData["type"] ?? "",
            "amount": (docData["amount"] as num).toDouble(),
            "note": docData["note"] ?? "",
            "paymentMethod": docData["paymentMethod"],
          };
        }).toList();

    // 2. Generate PDF Bytes
    final List<int> pdfData = await controller.generatePDF(name, data);

    try {
      // 3. Convert List<int> to Uint8List, then to JSUint8Array
      // 1. Convert your bytes to a JS-compatible Uint8Array
      final Uint8List uint8list = Uint8List.fromList(pdfData);
      final JSUint8Array jsBytes = uint8list.toJS;

      // 2. Create a JSArray and cast it to the specific view needed by Blob.
      // We cast it 'as JSArray<web.BlobPart>' because JSArray is an extension type.
      final blobParts = [jsBytes].toJS as JSArray<web.BlobPart>;

      // 3. Now the constructor will accept it perfectly
      final blob = web.Blob(
        blobParts,
        web.BlobPropertyBag(type: 'application/pdf'),
      );

      // 6. Create the Object URL
      final String url = web.URL.createObjectURL(blob);

      // 7. Create Anchor Element and trigger download
      final web.HTMLAnchorElement anchor =
          web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = "$name-ledger.pdf";
      anchor.click();

      // 8. Clean up
      web.URL.revokeObjectURL(url);
    } catch (e) {
      debugPrint("Error downloading PDF: $e");
    }
  }

  Widget _typeDropdown(RxString selected) {
    // Parameter matches RxString
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.value,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'credit', child: Text("CREDIT (BILL)")),
            DropdownMenuItem(value: 'debit', child: Text("DEBIT (PAY)")),
          ],
          onChanged: (v) => selected.value = v!,
        ),
      ),
    );
  }

  // --- 1. Dialog Header (Dark Slate) ---
  Widget _buildDialogHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111827), // darkSlate
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
          const SizedBox(width: 15),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
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

  // --- 2. Payment Dropdown (Logic for Debtor Methods) ---
  Widget _buildPaymentDropdown(
    List<Map<String, dynamic>> payments,
    Rx<Map<String, dynamic>?> selected,
  ) {
    return Obx(() {
      // Safety: Check if the current selected value actually exists in the payments list
      // This prevents the "There should be exactly one item" crash if the list changes
      final bool valueExists = payments.any((p) => p == selected.value);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Map<String, dynamic>>(
            // If the value doesn't exist in the list, show null to avoid crash
            value: valueExists ? selected.value : null,
            isExpanded: true,
            hint: const Text("Select Method", style: TextStyle(fontSize: 12)),
            items:
                payments.map((p) {
                  String type = p['type']?.toString().toUpperCase() ?? "CASH";
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      type,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
            onChanged: (v) => selected.value = v,
          ),
        ),
      );
    });
  }

  // --- 3. Section Label (Blue ERP style) ---
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B82F6), // activeAccent
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // --- 4. Standard Field (Consistent with other dialogs) ---
  Widget _buildFieldd(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 16, color: Colors.blueGrey),
        filled: true,
        fillColor: const Color(0xFFF3F4F6), // bgGrey
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      ),
    );
  }
}

String formatPaymentMethod(Map pm) {
  final type = pm['type']?.toString().toUpperCase() ?? "";
  if (type == 'BANK') {
    return "Method: Bank (${pm['bankName']})";
  } else if (type == 'CASH') {
    return "Method: Cash Payment";
  } else {
    return "Method: $type (${pm['number'] ?? ''})";
  }
}
